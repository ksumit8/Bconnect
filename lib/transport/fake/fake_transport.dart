import 'dart:async';
import 'dart:typed_data';

import '../../domain/models/audio.dart';
import '../../domain/protocol/advert_payload.dart';
import '../group_transport.dart';
import 'fake_hub.dart';

/// A [GroupTransport] backed by [FakeHub] instead of a radio.
///
/// The audio methods record their arguments rather than producing sound, so
/// tests can assert on mic and routing behaviour without a device.
class FakeTransport implements GroupTransport {
  FakeTransport(this._hub, {String? deviceId})
    : deviceId = deviceId ?? 'device${_counter++}' {
    _hub.register(this);
  }

  static int _counter = 0;

  final FakeHub _hub;
  final String deviceId;

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  bool isScanning = false;
  bool micEnabled = true;
  bool isTalking = false;
  AudioRoute audioRoute = AudioRoute.speaker;

  String? _advertisedName;
  AdvertPayload? _advertisedPayload;

  /// Visible to [FakeHub]; not part of [GroupTransport].
  void emit(TransportEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  Future<bool> isPeripheralSupported() async => true;

  @override
  Future<void> startAdvertising({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
  }) async {
    // Validates the name against the scan-response budget, exactly as the
    // real transport will (spec section 5.1).
    AdvertPayload.encodeName(groupName);

    _advertisedName = groupName;
    _advertisedPayload = AdvertPayload(
      groupId: groupId,
      memberCount: memberCount,
      isLocked: isLocked,
      isFull: isFull,
    );

    _hub.advertise(deviceId, groupName, _advertisedPayload!);
  }

  @override
  Future<void> updateAdvertisement({
    required int memberCount,
    required bool isFull,
  }) async {
    final current = _advertisedPayload;
    if (current == null) {
      throw const TransportException('not advertising');
    }

    _advertisedPayload = AdvertPayload(
      groupId: current.groupId,
      memberCount: memberCount,
      isLocked: current.isLocked,
      isFull: isFull,
    );

    _hub.advertise(deviceId, _advertisedName!, _advertisedPayload!);
  }

  @override
  Future<void> stopAdvertising() async {
    _advertisedName = null;
    _advertisedPayload = null;
    _hub.stopAdvertising(deviceId);
  }

  @override
  Future<void> startScan() async {
    isScanning = true;
    _hub.deliverCurrentAdverts(this);
  }

  @override
  Future<void> stopScan() async => isScanning = false;

  @override
  Future<String> connect(String deviceId) async => _hub.connect(this, deviceId);

  @override
  Future<void> disconnect(String peerId) async => _hub.disconnect(this, peerId);

  @override
  Future<void> sendControl(String peerId, Uint8List bytes) async =>
      _hub.send(this, peerId, bytes);

  @override
  Future<void> setMicEnabled(bool enabled) async => micEnabled = enabled;

  @override
  Future<void> setAudioRoute(AudioRoute route) async => audioRoute = route;

  @override
  Future<void> startTalking() async => isTalking = true;

  @override
  Future<void> stopTalking() async => isTalking = false;

  @override
  Future<void> dispose() async {
    _hub.unregister(this);
    await _events.close();
  }
}
