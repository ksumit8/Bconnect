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
          _centrals[id] = e.central;
          _emit(PeerConnectedEvent(id));
        } else {
          _centrals.remove(id);
          _emit(PeerDisconnectedEvent(id));
        }
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
  Future<String> connect(String deviceId) async =>
      throw UnimplementedError('Task 7');

  @override
  Future<void> disconnect(String peerId) async =>
      throw UnimplementedError('Task 7');

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

    // Client path is added in Task 7.
    throw TransportException('no connection $peerId');
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
    await _events.close();
  }
}
