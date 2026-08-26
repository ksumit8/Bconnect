/// Wire-level constants shared by every peer (spec sections 5.1, 5.4, 5.5).
///
/// If the Phase 0 aggregate throughput test fails (spec section 9.1),
/// [maxMembers] and [maxConcurrentTalkers] are the only values that change.
abstract final class ProtocolLimits {
  static const int protocolVersion = 1;

  /// Distinguishes Bconnect adverts from other apps sharing the 16-bit
  /// service UUID.
  static const int magic = 0xB1C7;

  /// Host plus seven clients.
  static const int maxMembers = 8;

  static const int maxConcurrentTalkers = 3;

  /// Scan-response capacity for the group name.
  static const int maxGroupNameBytes = 29;

  static const int nonceLength = 16;

  /// Truncated HMAC-SHA256.
  static const int passwordProofLength = 16;

  /// magic(2) + version(1) + flags(1) + memberCount(1) + groupId(2)
  static const int serviceDataLength = 7;

  /// A scan result older than this is dropped from the discovery list.
  static const Duration advertTtl = Duration(seconds: 10);

  static const int flagLocked = 0x01;
  static const int flagFull = 0x02;

  /// The largest value a one-byte length prefix can carry in the control
  /// frame wire format (spec section 5.3).
  static const int maxFieldBytes = 255;

  /// The UI enforces this in a later task; it belongs with the other wire
  /// constants. The codec itself does not need to reference it.
  static const int maxDisplayNameBytes = 63;
}
