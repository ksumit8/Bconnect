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

  @override
  Stream<TransportEvent> get events => _events.stream;

  // ignore: unused_element
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
    await _peripheral.stopAdvertising();
  }

  // --- Client role: Task 6 and 7 -----------------------------------------

  @override
  Future<void> startScan() async => throw UnimplementedError('Task 6');

  @override
  Future<void> stopScan() async => throw UnimplementedError('Task 6');

  @override
  Future<String> connect(String deviceId) async =>
      throw UnimplementedError('Task 7');

  @override
  Future<void> disconnect(String peerId) async =>
      throw UnimplementedError('Task 7');

  @override
  Future<void> sendControl(String peerId, Uint8List bytes) async =>
      throw UnimplementedError('Task 5');

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
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _events.close();
  }
}
