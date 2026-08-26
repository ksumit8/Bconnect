import 'dart:typed_data';

import '../../domain/models/discovered_group.dart';
import '../../domain/protocol/advert_payload.dart';
import '../group_transport.dart';
import 'fake_transport.dart';

class _Advert {
  const _Advert(this.name, this.payload, this.rssi);

  final String name;
  final AdvertPayload payload;
  final int rssi;
}

class _Connection {
  const _Connection(this.id, this.a, this.b);

  final String id;
  final FakeTransport a;
  final FakeTransport b;

  FakeTransport other(FakeTransport self) => identical(self, a) ? b : a;

  bool involves(FakeTransport t) => identical(t, a) || identical(t, b);
}

/// In-memory broker standing in for the BLE radio.
///
/// Every peer in a test shares one hub. Because it is an object rather than a
/// singleton, tests are isolated from each other.
class FakeHub {
  FakeHub({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  final Map<String, FakeTransport> _peers = {};
  final Map<String, _Advert> _adverts = {};
  final List<_Connection> _connections = [];

  int _nextConnectionId = 0;

  void register(FakeTransport peer) => _peers[peer.deviceId] = peer;

  void unregister(FakeTransport peer) {
    _adverts.remove(peer.deviceId);
    _peers.remove(peer.deviceId);

    for (final c in _connections.where((c) => c.involves(peer)).toList()) {
      _closeConnection(c);
    }
  }

  void advertise(
    String deviceId,
    String name,
    AdvertPayload payload, {
    int rssi = -55,
  }) {
    _adverts[deviceId] = _Advert(name, payload, rssi);
    _broadcastScanResult(deviceId);
  }

  void stopAdvertising(String deviceId) => _adverts.remove(deviceId);

  /// Delivers the current adverts to a peer that has just started scanning.
  ///
  /// Real scan results never arrive synchronously with `startScan()`, so this
  /// defers delivery to the next event-loop turn. That also gives a caller
  /// that subscribes to `events` immediately after `await startScan()` (as
  /// opposed to before) a chance to attach before the replay fires.
  void deliverCurrentAdverts(FakeTransport scanner) {
    for (final deviceId in _adverts.keys) {
      if (deviceId == scanner.deviceId) continue;
      final group = _toGroup(deviceId);
      Future(() => scanner.emit(ScanResultEvent(group)));
    }
  }

  void _broadcastScanResult(String deviceId) {
    final group = _toGroup(deviceId);
    for (final peer in _peers.values) {
      if (peer.deviceId == deviceId || !peer.isScanning) continue;
      Future(() => peer.emit(ScanResultEvent(group)));
    }
  }

  DiscoveredGroup _toGroup(String deviceId) {
    final advert = _adverts[deviceId]!;

    return DiscoveredGroup(
      groupId: advert.payload.groupIdHex,
      deviceId: deviceId,
      name: advert.name,
      memberCount: advert.payload.memberCount,
      isLocked: advert.payload.isLocked,
      isFull: advert.payload.isFull,
      rssi: advert.rssi,
      lastSeen: _clock(),
    );
  }

  String connect(FakeTransport client, String hostDeviceId) {
    final host = _peers[hostDeviceId];
    if (host == null) {
      throw TransportException('no device with id $hostDeviceId');
    }

    final id = 'conn${_nextConnectionId++}';
    _connections.add(_Connection(id, client, host));

    client.emit(PeerConnectedEvent(id));
    host.emit(PeerConnectedEvent(id));

    return id;
  }

  void send(FakeTransport from, String peerId, Uint8List bytes) {
    final connection = _find(peerId, from);
    connection.other(from).emit(ControlMessageEvent(peerId, bytes));
  }

  void disconnect(FakeTransport from, String peerId) =>
      _closeConnection(_find(peerId, from));

  _Connection _find(String peerId, FakeTransport from) {
    for (final c in _connections) {
      if (c.id == peerId && c.involves(from)) return c;
    }
    throw TransportException('no connection $peerId on ${from.deviceId}');
  }

  void _closeConnection(_Connection c) {
    _connections.remove(c);
    c.a.emit(PeerDisconnectedEvent(c.id));
    c.b.emit(PeerDisconnectedEvent(c.id));
  }

  void reset() {
    _peers.clear();
    _adverts.clear();
    _connections.clear();
    _nextConnectionId = 0;
  }
}
