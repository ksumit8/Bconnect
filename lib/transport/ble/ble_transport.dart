import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../../domain/models/audio.dart';
import '../group_transport.dart';
import 'ble_uuids.dart';

/// The real Bluetooth LE transport.
///
/// One device plays one role at a time: hosting uses [PeripheralManager]
/// (advertise + GATT server), joining uses [CentralManager] (scan + connect).
/// Both managers are created up front because the user can switch roles
/// without restarting the app.
///
/// Peer identity note: BLE gives each end its own view of a connection — the
/// host sees a Central, the client sees a Peripheral. That is fine. Neither
/// `HostSession` nor `ClientSession` ever compares its peerId to the other
/// side's; each only passes its own back to `sendControl`. Do not try to
/// negotiate a shared id.
class BleTransport implements GroupTransport {
  BleTransport({PeripheralManager? peripheral, CentralManager? central})
    : _injectedPeripheral = peripheral,
      _injectedCentral = central;

  final PeripheralManager? _injectedPeripheral;
  final CentralManager? _injectedCentral;

  // Resolved on first use, never at construction. `PeripheralManager()` and
  // `CentralManager()` reach into the platform plugin and throw outright where
  // it is unimplemented — including the Dart VM that `flutter test` runs on. A
  // transport that cannot be constructed off-device cannot have its interface
  // conformance tested, and a provider that builds one at app start would
  // probe the radio before permissions have been asked for. Both managers are
  // platform singletons, so deferring costs nothing on Android.
  PeripheralManager? _peripheralCache;
  CentralManager? _centralCache;

  PeripheralManager get _peripheral =>
      _injectedPeripheral ?? (_peripheralCache ??= PeripheralManager());

  CentralManager get _central =>
      _injectedCentral ?? (_centralCache ??= CentralManager());

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  final List<StreamSubscription<dynamic>> _subs = [];

  bool _initialised = false;

  // Retained so updateAdvertisement can rebuild the packet: BLE has no
  // "modify advert in place", only stop-and-restart with fresh bytes.
  String? _advertisedName;
  int? _advertisedGroupId;
  bool _advertisedLocked = false;

  GATTCharacteristic? _controlCharacteristic;
  final Map<String, Central> _centrals = {};
  bool _serviceAdded = false;

  final Map<String, Peripheral> _discovered = {};
  StreamSubscription<DiscoveredEventArgs>? _discoverySub;

  final Map<String, Peripheral> _connected = {};
  final Map<String, GATTCharacteristic> _clientControl = {};

  // Control frames that arrived before `connect()` returned, keyed by peerId.
  //
  // The host sends its CHALLENGE the moment our CCCD write lands — which
  // happens inside `connect()`, before the future completes. `ClientSession`
  // only learns its peerId FROM that future, and drops any event whose peerId
  // does not match, so a challenge delivered early is thrown away and the join
  // hangs forever. Whether it lands early is a race: it did not on a cold
  // link, and did on a warm one. Buffer, then flush once the caller has had a
  // turn.
  final Map<String, List<Uint8List>> _earlyControl = {};

  @override
  Stream<TransportEvent> get events => _events.stream;

  void _emit(TransportEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  /// Must be awaited once before any other method.
  ///
  /// `authorize()` is deliberately guarded: `bluetooth_low_energy`'s
  /// implementation never completes when permissions are already granted and
  /// the adapter is on, which hangs the app on a blank screen (spec 9.1).
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    if (_peripheral.state != BluetoothLowEnergyState.poweredOn) {
      try {
        await _peripheral.authorize().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // Permissions were already granted; carry on.
      }
    }
    if (_central.state != BluetoothLowEnergyState.poweredOn) {
      try {
        await _central.authorize().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // As above.
      }
    }

    // Notifications from a host arrive here.
    _subs.add(
      _central.characteristicNotified.listen((e) {
        if (e.characteristic.uuid != BleUuids.control) return;
        final id = e.peripheral.uuid.toString();
        final bytes = Uint8List.fromList(e.value);
        final pending = _earlyControl[id];
        if (pending != null) {
          pending.add(bytes);
          return;
        }
        _emit(ControlMessageEvent(id, bytes));
      }),
    );

    // A host going away, or moving out of range.
    _subs.add(
      _central.connectionStateChanged.listen((e) {
        if (e.state == ConnectionState.disconnected) {
          final id = e.peripheral.uuid.toString();
          if (_connected.remove(id) != null) {
            _clientControl.remove(id);
            _earlyControl.remove(id);
            _emit(PeerDisconnectedEvent(id));
          }
        }
      }),
    );
  }

  @override
  Future<bool> isPeripheralSupported() async {
    await init();
    return _peripheral.state == BluetoothLowEnergyState.poweredOn;
  }

  // --- Host role: Task 4 and 5 -------------------------------------------

  /// Publishes the GATT service and wires the host-side listeners.
  ///
  /// Idempotent: `startAdvertising` may be called more than once (creating a
  /// group after ending a previous one), and re-adding a service throws.
  Future<void> _ensureHostService() async {
    if (_serviceAdded) return;
    _serviceAdded = true;

    final control = GATTCharacteristic.mutable(
      uuid: BleUuids.control,
      properties: [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.write,
        GATTCharacteristicProperty.writeWithoutResponse,
        GATTCharacteristicProperty.notify,
      ],
      permissions: [
        GATTCharacteristicPermission.read,
        GATTCharacteristicPermission.write,
      ],
      descriptors: [],
    );
    _controlCharacteristic = control;

    await _peripheral.removeAllServices();
    await _peripheral.addService(
      GATTService(
        uuid: BleUuids.service,
        isPrimary: true,
        includedServices: [],
        characteristics: [control],
      ),
    );

    // Note: `bluetooth_low_energy` exports `ConnectionState`, and so does
    // `package:flutter/material.dart`. This file does not import material, so
    // the reference below is unambiguous. If you ever add a material import
    // here, alias one of them (`import '...' as ble show ConnectionState;`)
    // rather than renaming anything.
    _subs.add(
      _peripheral.connectionStateChanged.listen((e) {
        final id = e.central.uuid.toString();
        if (e.state == ConnectionState.connected) {
          // Track the central, but do NOT report the peer as connected yet —
          // see the notify-state listener below for why.
          _centrals[id] = e.central;
        } else {
          _centrals.remove(id);
          _emit(PeerDisconnectedEvent(id));
        }
      }),
    );

    // A peer counts as connected only once it has SUBSCRIBED, not merely when
    // the GATT link opens.
    //
    // `HostSession` answers `PeerConnectedEvent` by sending a CHALLENGE, and
    // the host's only way to send is `notifyCharacteristic`. A notification
    // published before the client has written the CCCD is dropped by the stack
    // silently — no error on either side. Emitting on link-up therefore races
    // the client's subscribe and, when it loses, the client sits on the
    // password screen forever waiting for a challenge that was thrown away.
    // Subscription is the first moment the host can actually be heard.
    _subs.add(
      _peripheral.characteristicNotifyStateChanged.listen((e) {
        if (e.characteristic.uuid != BleUuids.control) return;
        if (!e.state) return;
        final id = e.central.uuid.toString();
        _centrals[id] = e.central;
        _emit(PeerConnectedEvent(id));
      }),
    );

    // A client's control frame arrives as a write request. Respond first —
    // an unanswered request stalls that client's GATT queue — then surface it.
    _subs.add(
      _peripheral.characteristicWriteRequested.listen((e) async {
        final value = Uint8List.fromList(e.request.value);
        try {
          await _peripheral.respondWriteRequest(e.request);
        } catch (_) {
          // The central vanished mid-request; the disconnect event handles it.
        }
        _centrals[e.central.uuid.toString()] = e.central;
        _emit(ControlMessageEvent(e.central.uuid.toString(), value));
      }),
    );

    // Descriptor requests MUST be answered, and this one is load-bearing.
    //
    // When a client subscribes, `setCharacteristicNotifyState` writes the
    // Client Characteristic Configuration descriptor (0x2902). Android adds
    // that descriptor to our service automatically, but `bluetooth_low_energy`
    // does NOT auto-respond to writes on it — `PeripheralManagerImpl.kt:456`
    // forwards the request to Dart and waits for us. Leave this unhandled and
    // the client's subscribe never completes, so `connect()` never returns and
    // the join spinner spins forever with no error anywhere. There is nothing
    // for us to store: Android tracks the subscription itself.
    _subs.add(
      _peripheral.descriptorWriteRequested.listen((e) async {
        try {
          await _peripheral.respondWriteRequest(e.request);
        } catch (_) {
          // The central vanished mid-request.
        }
      }),
    );

    _subs.add(
      _peripheral.descriptorReadRequested.listen((e) async {
        try {
          await _peripheral.respondReadRequestWithValue(
            e.request,
            value: Uint8List(0),
          );
        } catch (_) {
          // As above.
        }
      }),
    );

    // The control characteristic is a message pipe, not a value, so there is
    // nothing meaningful to read from it. It still declares READ, because a
    // central that cannot read the characteristic cannot discover it on some
    // stacks — and an unanswered read request stalls that central's GATT queue
    // exactly the way an unanswered write does. So: answer, with nothing.
    _subs.add(
      _peripheral.characteristicReadRequested.listen((e) async {
        try {
          await _peripheral.respondReadRequestWithValue(
            e.request,
            value: Uint8List(0),
          );
        } catch (_) {
          // As above.
        }
      }),
    );
  }

  @override
  Future<void> startAdvertising({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
    // Accepted only to match the interface. A real radio reports the RSSI it
    // measures; it cannot advertise a chosen one, so this value is ignored.
    int rssi = -55,
  }) async {
    await init();
    await _ensureHostService();

    _advertisedName = groupName;
    _advertisedGroupId = groupId;
    _advertisedLocked = isLocked;

    await _peripheral.stopAdvertising();
    await _peripheral.startAdvertising(
      BleAdvert.encode(
        groupName: groupName,
        groupId: groupId,
        memberCount: memberCount,
        isLocked: isLocked,
        isFull: isFull,
      ),
    );
  }

  @override
  Future<void> updateAdvertisement({
    required int memberCount,
    required bool isFull,
  }) async {
    final name = _advertisedName;
    final id = _advertisedGroupId;
    if (name == null || id == null) {
      throw const TransportException('not advertising');
    }

    // BLE has no "modify advert in place": stop and restart with new data.
    await _peripheral.stopAdvertising();
    await _peripheral.startAdvertising(
      BleAdvert.encode(
        groupName: name,
        groupId: id,
        memberCount: memberCount,
        isLocked: _advertisedLocked,
        isFull: isFull,
      ),
    );
  }

  @override
  Future<void> stopAdvertising() async {
    _advertisedName = null;
    _advertisedGroupId = null;
    _centrals.clear();
    // The GATT service deliberately stays published: HostSession.stop() calls
    // stopAdvertising, and a later startAdvertising must still work.
    await _peripheral.stopAdvertising();
  }

  // --- Client role: Task 6 and 7 -----------------------------------------

  @override
  Future<void> startScan() async {
    await init();

    // One listener for the life of the transport, attached before discovery
    // starts so no advert is missed. `discoveredGroupsProvider` calls
    // startScan every time the Discover screen is opened; a fresh listener per
    // call would decode every advert once per visit and never be released
    // until dispose().
    _discoverySub ??= _central.discovered.listen((e) {
      final group = BleAdvert.decode(
        e.advertisement,
        deviceId: e.peripheral.uuid.toString(),
        rssi: e.rssi,
        seenAt: DateTime.now(),
      );
      // decode() returns null for anything that is not a current-version
      // Bconnect advert, including other apps on the same service UUID.
      if (group == null) return;

      _discovered[group.deviceId] = e.peripheral;
      _emit(ScanResultEvent(group));
    });

    // Unfiltered: filtering by service UUID hides the difference between
    // "nothing on air" and "advertising without our UUID", which makes field
    // diagnosis much harder. decode() does the filtering instead.
    await _central.startDiscovery();
  }

  @override
  Future<void> stopScan() async {
    await _central.stopDiscovery();
  }

  @override
  Future<String> connect(String deviceId) async {
    final peripheral = _discovered[deviceId];
    if (peripheral == null) {
      throw TransportException('no device with id $deviceId');
    }

    // Stop scanning first. An active LE scan starves the connection attempt on
    // Android: the radio keeps hopping through the scan window instead of
    // completing the connection, and `connect()` simply never calls back until
    // the stack gives up ~25s later. `discoveredGroupsProvider` is still
    // scanning at this point because the Discover screen is what navigated
    // here, so this is the normal path, not an edge case.
    try {
      await _central.stopDiscovery();
    } catch (_) {
      // Not scanning; nothing to stop.
    }

    try {
      await _central.connect(peripheral);
    } catch (e) {
      throw TransportException('connect failed: $e');
    }

    final peerId = peripheral.uuid.toString();
    _connected[peerId] = peripheral;

    // A larger MTU is requested up front. It is not fatal if the peer
    // refuses; control frames are small. Plan B2's audio needs the headroom.
    try {
      await _central.requestMTU(peripheral, mtu: 517);
    } catch (_) {}

    final services = await _central.discoverGATT(peripheral);
    final service = services.firstWhere(
      (s) => s.uuid == BleUuids.service,
      orElse: () =>
          throw const TransportException('peer is not a Bconnect host'),
    );
    final control = service.characteristics.firstWhere(
      (c) => c.uuid == BleUuids.control,
      orElse: () =>
          throw const TransportException('host has no control characteristic'),
    );
    _clientControl[peerId] = control;

    // Start buffering before subscribing: the host answers the CCCD write
    // immediately, and anything it sends now would otherwise reach
    // ClientSession before it knows its own peerId.
    _earlyControl[peerId] = [];
    await _central.setCharacteristicNotifyState(
      peripheral,
      control,
      state: true,
    );

    _emit(PeerConnectedEvent(peerId));

    // Flush on the event loop rather than a microtask, so the caller's
    // `_peerId = await connect(...)` has already run.
    Future<void>.delayed(Duration.zero, () {
      final pending = _earlyControl.remove(peerId);
      if (pending == null) return;
      for (final bytes in pending) {
        _emit(ControlMessageEvent(peerId, bytes));
      }
    });

    return peerId;
  }

  @override
  Future<void> disconnect(String peerId) async {
    final peripheral = _connected.remove(peerId);
    _clientControl.remove(peerId);
    _earlyControl.remove(peerId);

    // Host path: the peer is a central we are serving.
    final central = _centrals.remove(peerId);
    if (central != null) {
      try {
        await _peripheral.disconnect(central);
      } catch (_) {}
      _emit(PeerDisconnectedEvent(peerId));
      return;
    }

    if (peripheral == null) {
      throw TransportException('no connection $peerId');
    }
    try {
      await _central.disconnect(peripheral);
    } catch (_) {}
    _emit(PeerDisconnectedEvent(peerId));
  }

  @override
  Future<void> sendControl(String peerId, Uint8List bytes) async {
    // Host path: notify the central on the control characteristic.
    final central = _centrals[peerId];
    final control = _controlCharacteristic;
    if (central != null && control != null) {
      try {
        await _peripheral.notifyCharacteristic(central, control, value: bytes);
      } catch (e) {
        throw TransportException('notify failed for $peerId: $e');
      }
      return;
    }

    // Client path: write to the host's control characteristic.
    final peripheral = _connected[peerId];
    final clientControl = _clientControl[peerId];
    if (peripheral == null || clientControl == null) {
      throw TransportException('no connection $peerId');
    }
    try {
      // withResponse: control frames carry the join handshake, and a silently
      // dropped JOIN_REQUEST would strand the client on the password screen.
      await _central.writeCharacteristic(
        peripheral,
        clientControl,
        value: bytes,
        type: GATTCharacteristicWriteType.withResponse,
      );
    } catch (e) {
      throw TransportException('write failed for $peerId: $e');
    }
  }

  // --- Audio: Plan B2 ----------------------------------------------------
  //
  // Inert on purpose. GroupScreen calls startTalking/stopTalking on every
  // press of the talk button, so these must not throw.

  @override
  Future<void> setMicEnabled(bool enabled) async {}

  @override
  Future<void> setAudioRoute(AudioRoute route) async {}

  @override
  Future<void> startTalking() async {}

  @override
  Future<void> stopTalking() async {}

  @override
  Future<void> dispose() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _discovered.clear();
    _earlyControl.clear();
    _connected.clear();
    _clientControl.clear();
    _centrals.clear();
    await _events.close();
  }
}
