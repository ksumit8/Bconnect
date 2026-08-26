import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/protocol/advert_payload.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';

void main() {
  group('AdvertPayload service data', () {
    test('encodes to exactly the advertised service-data length', () {
      const p = AdvertPayload(
        groupId: 0x1A2B,
        memberCount: 3,
        isLocked: true,
        isFull: false,
      );

      expect(p.encode().length, ProtocolLimits.serviceDataLength);
    });

    test('round-trips every field', () {
      const p = AdvertPayload(
        groupId: 0x1A2B,
        memberCount: 3,
        isLocked: true,
        isFull: false,
      );

      expect(AdvertPayload.decode(p.encode()), equals(p));
    });

    test('round-trips the full flag independently of the locked flag', () {
      const p = AdvertPayload(
        groupId: 0xFFFF,
        memberCount: ProtocolLimits.maxMembers,
        isLocked: false,
        isFull: true,
      );

      final decoded = AdvertPayload.decode(p.encode())!;

      expect(decoded.isFull, isTrue);
      expect(decoded.isLocked, isFalse);
    });

    test('exposes the group id as four lowercase hex digits', () {
      const p = AdvertPayload(
        groupId: 0x0A2B,
        memberCount: 1,
        isLocked: false,
        isFull: false,
      );

      expect(p.groupIdHex, '0a2b');
    });

    test('rejects data of the wrong length', () {
      expect(AdvertPayload.decode(Uint8List(6)), isNull);
      expect(AdvertPayload.decode(Uint8List(8)), isNull);
    });

    test('rejects data whose magic does not match', () {
      const p = AdvertPayload(
        groupId: 1,
        memberCount: 1,
        isLocked: false,
        isFull: false,
      );
      final bytes = p.encode();
      bytes[0] = 0x00;

      expect(AdvertPayload.decode(bytes), isNull);
    });

    test('rejects data from an unknown protocol version', () {
      const p = AdvertPayload(
        groupId: 1,
        memberCount: 1,
        isLocked: false,
        isFull: false,
      );
      final bytes = p.encode();
      bytes[2] = 99;

      expect(AdvertPayload.decode(bytes), isNull);
    });
  });

  group('AdvertPayload scan-response name', () {
    test('round-trips an ASCII name', () {
      expect(
        AdvertPayload.decodeName(AdvertPayload.encodeName('Team Alpha')),
        'Team Alpha',
      );
    });

    test('round-trips a multi-byte UTF-8 name', () {
      expect(
        AdvertPayload.decodeName(AdvertPayload.encodeName('Grüße 🎧')),
        'Grüße 🎧',
      );
    });

    test('accepts a name of exactly the byte limit', () {
      final name = 'a' * ProtocolLimits.maxGroupNameBytes;

      expect(AdvertPayload.encodeName(name).length,
          ProtocolLimits.maxGroupNameBytes);
    });

    test('rejects a name one byte over the limit', () {
      final name = 'a' * (ProtocolLimits.maxGroupNameBytes + 1);

      expect(
        () => AdvertPayload.encodeName(name),
        throwsA(isA<GroupNameTooLongException>()),
      );
    });

    test('measures the limit in UTF-8 bytes, not characters', () {
      // 15 two-byte characters is 30 bytes: over the 29-byte limit even
      // though it is only 15 characters.
      final name = 'ü' * 15;

      expect(
        () => AdvertPayload.encodeName(name),
        throwsA(isA<GroupNameTooLongException>()),
      );
    });
  });
}
