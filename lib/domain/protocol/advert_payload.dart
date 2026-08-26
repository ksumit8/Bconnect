import 'dart:convert';
import 'dart:typed_data';

import 'protocol_limits.dart';

class GroupNameTooLongException implements Exception {
  const GroupNameTooLongException(this.byteLength);

  final int byteLength;

  @override
  String toString() =>
      'Group name is $byteLength UTF-8 bytes; the limit is '
      '${ProtocolLimits.maxGroupNameBytes}.';
}

/// The BLE advertisement service data (spec section 5.1).
///
/// This is a plain class rather than a freezed model because its byte layout
/// is part of the wire protocol.
class AdvertPayload {
  const AdvertPayload({
    required this.groupId,
    required this.memberCount,
    required this.isLocked,
    required this.isFull,
  });

  final int groupId;
  final int memberCount;
  final bool isLocked;
  final bool isFull;

  String get groupIdHex => groupId.toRadixString(16).padLeft(4, '0');

  Uint8List encode() {
    final bytes = Uint8List(ProtocolLimits.serviceDataLength);
    final view = ByteData.view(bytes.buffer);

    view.setUint16(0, ProtocolLimits.magic);
    view.setUint8(2, ProtocolLimits.protocolVersion);
    view.setUint8(
      3,
      (isLocked ? ProtocolLimits.flagLocked : 0) |
          (isFull ? ProtocolLimits.flagFull : 0),
    );
    view.setUint8(4, memberCount);
    view.setUint16(5, groupId);

    return bytes;
  }

  /// Returns null for anything that is not a current-version Bconnect advert.
  static AdvertPayload? decode(Uint8List bytes) {
    if (bytes.length != ProtocolLimits.serviceDataLength) return null;

    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

    if (view.getUint16(0) != ProtocolLimits.magic) return null;
    if (view.getUint8(2) != ProtocolLimits.protocolVersion) return null;

    final flags = view.getUint8(3);

    return AdvertPayload(
      groupId: view.getUint16(5),
      memberCount: view.getUint8(4),
      isLocked: flags & ProtocolLimits.flagLocked != 0,
      isFull: flags & ProtocolLimits.flagFull != 0,
    );
  }

  /// The group name travels in the scan response, not the advertisement,
  /// which is what buys 29 bytes instead of roughly 15 (spec section 5.1).
  static Uint8List encodeName(String name) {
    final bytes = utf8.encode(name);
    if (bytes.length > ProtocolLimits.maxGroupNameBytes) {
      throw GroupNameTooLongException(bytes.length);
    }
    return Uint8List.fromList(bytes);
  }

  static String decodeName(Uint8List bytes) => utf8.decode(bytes);

  @override
  bool operator ==(Object other) =>
      other is AdvertPayload &&
      other.groupId == groupId &&
      other.memberCount == memberCount &&
      other.isLocked == isLocked &&
      other.isFull == isFull;

  @override
  int get hashCode => Object.hash(groupId, memberCount, isLocked, isFull);

  @override
  String toString() =>
      'AdvertPayload(groupId: $groupIdHex, memberCount: $memberCount, '
      'isLocked: $isLocked, isFull: $isFull)';
}
