import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'protocol_limits.dart';

/// The join challenge (spec section 5.3).
///
/// The host issues a nonce; the client returns
/// `HMAC-SHA256(password, nonce)` truncated to 16 bytes. The password itself
/// never crosses the wire, and a captured proof cannot be replayed against a
/// later nonce.
abstract final class PasswordProof {
  static final Random _defaultRandom = Random.secure();

  static Uint8List generateNonce([Random? random]) {
    final source = random ?? _defaultRandom;
    final nonce = Uint8List(ProtocolLimits.nonceLength);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = source.nextInt(256);
    }
    return nonce;
  }

  static Uint8List compute({
    required String password,
    required Uint8List nonce,
  }) {
    final mac = Hmac(sha256, utf8.encode(password)).convert(nonce);
    return Uint8List.fromList(
      mac.bytes.sublist(0, ProtocolLimits.passwordProofLength),
    );
  }

  static bool verify({
    required String password,
    required Uint8List nonce,
    required Uint8List proof,
  }) {
    final expected = compute(password: password, nonce: nonce);
    if (proof.length != expected.length) return false;

    // Constant-time comparison: always inspect every byte so that the time
    // taken does not reveal how much of the proof was correct.
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ proof[i];
    }
    return diff == 0;
  }
}
