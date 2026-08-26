import 'dart:typed_data';

import '../domain/models/audio.dart';
import '../domain/models/discovered_group.dart';

class TransportException implements Exception {
  const TransportException(this.message);

  final String message;

  @override
  String toString() => 'TransportException: $message';
}

/// Events raised by a transport.
///
/// Plan B adds an audio *level* event for the meters. It must never carry
/// audio frames: those stay entirely inside the platform layer
/// (spec section 3.5).
sealed class TransportEvent {
  const TransportEvent();
}

final class ScanResultEvent extends TransportEvent {
  const ScanResultEvent(this.group);

  final DiscoveredGroup group;
}

final class PeerConnectedEvent extends TransportEvent {
  const PeerConnectedEvent(this.peerId);

  final String peerId;
}

final class PeerDisconnectedEvent extends TransportEvent {
  const PeerDisconnectedEvent(this.peerId);

  final String peerId;
}

final class ControlMessageEvent extends TransportEvent {
  const ControlMessageEvent(this.peerId, this.bytes);

  final String peerId;
  final Uint8List bytes;
}

final class TransportErrorEvent extends TransportEvent {
  const TransportErrorEvent(this.message);

  final String message;
}

/// `Iterable` has `whereType` in the standard library; `Stream` does not.
/// Session code (Tasks 8-9) and tests filter [GroupTransport.events] by
/// [TransportEvent] subtype constantly, so it lives next to the event union.
extension StreamWhereTypeX<T> on Stream<T> {
  Stream<R> whereType<R>() => where((event) => event is R).cast<R>();
}

/// The seam between the session layer and the radio (spec section 4).
///
/// A connection has a single id shared by both ends, so host and client code
/// stay symmetric.
abstract interface class GroupTransport {
  Stream<TransportEvent> get events;

  /// False on devices whose Bluetooth stack cannot act as a peripheral, which
  /// disables hosting but not joining (spec section 8).
  Future<bool> isPeripheralSupported();

  Future<void> startAdvertising({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
  });

  /// Re-advertises with a changed member count or full flag.
  Future<void> updateAdvertisement({
    required int memberCount,
    required bool isFull,
  });

  Future<void> stopAdvertising();

  Future<void> startScan();
  Future<void> stopScan();

  /// Returns the id of the new connection.
  Future<String> connect(String deviceId);

  Future<void> disconnect(String peerId);

  Future<void> sendControl(String peerId, Uint8List bytes);

  Future<void> setMicEnabled(bool enabled);
  Future<void> setAudioRoute(AudioRoute route);
  Future<void> startTalking();
  Future<void> stopTalking();

  Future<void> dispose();
}
