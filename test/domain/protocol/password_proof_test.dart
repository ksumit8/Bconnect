import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/protocol/password_proof.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';

void main() {
  final nonce = PasswordProof.generateNonce(Random(1));

  group('generateNonce', () {
    test('returns the advertised nonce length', () {
      expect(nonce.length, ProtocolLimits.nonceLength);
    });

    test('returns different values across calls', () {
      final a = PasswordProof.generateNonce();
      final b = PasswordProof.generateNonce();

      expect(a, isNot(equals(b)));
    });
  });

  group('compute', () {
    test('returns the truncated proof length', () {
      expect(
        PasswordProof.compute(password: 'hunter2', nonce: nonce).length,
        ProtocolLimits.passwordProofLength,
      );
    });

    test('is deterministic for the same password and nonce', () {
      expect(
        PasswordProof.compute(password: 'hunter2', nonce: nonce),
        equals(PasswordProof.compute(password: 'hunter2', nonce: nonce)),
      );
    });

    test('differs for a different password', () {
      expect(
        PasswordProof.compute(password: 'hunter2', nonce: nonce),
        isNot(equals(PasswordProof.compute(password: 'hunter3', nonce: nonce))),
      );
    });

    test('differs for a different nonce, which is what defeats replay', () {
      final other = PasswordProof.generateNonce(Random(2));

      expect(
        PasswordProof.compute(password: 'hunter2', nonce: nonce),
        isNot(equals(PasswordProof.compute(password: 'hunter2', nonce: other))),
      );
    });
  });

  group('verify', () {
    test('accepts a proof computed from the same password', () {
      final proof = PasswordProof.compute(password: 'hunter2', nonce: nonce);

      expect(
        PasswordProof.verify(
            password: 'hunter2', nonce: nonce, proof: proof),
        isTrue,
      );
    });

    test('rejects a proof computed from a different password', () {
      final proof = PasswordProof.compute(password: 'wrong', nonce: nonce);

      expect(
        PasswordProof.verify(
            password: 'hunter2', nonce: nonce, proof: proof),
        isFalse,
      );
    });

    test('rejects a proof replayed against a different nonce', () {
      final proof = PasswordProof.compute(password: 'hunter2', nonce: nonce);
      final later = PasswordProof.generateNonce(Random(3));

      expect(
        PasswordProof.verify(
            password: 'hunter2', nonce: later, proof: proof),
        isFalse,
      );
    });

    test('rejects a proof of the wrong length', () {
      expect(
        PasswordProof.verify(
            password: 'hunter2', nonce: nonce, proof: Uint8List(4)),
        isFalse,
      );
    });
  });
}
