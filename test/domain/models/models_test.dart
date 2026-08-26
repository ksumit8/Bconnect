import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/audio.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/member.dart';

void main() {
  group('Member', () {
    test('defaults to a non-host, non-self, online, silent member', () {
      const m = Member(id: '1', displayName: 'Device 1');

      expect(m.isHost, isFalse);
      expect(m.isSelf, isFalse);
      expect(m.presence, MemberPresence.online);
      expect(m.isTalking, isFalse);
    });

    test('has value equality', () {
      const a = Member(id: '1', displayName: 'You', isHost: true);
      const b = Member(id: '1', displayName: 'You', isHost: true);

      expect(a, equals(b));
    });

    test('copyWith replaces only the named field', () {
      const m = Member(id: '1', displayName: 'You');

      expect(m.copyWith(isTalking: true).isTalking, isTrue);
      expect(m.copyWith(isTalking: true).displayName, 'You');
    });
  });

  group('GroupConfig', () {
    test('is unlocked when the password is null or empty', () {
      expect(const GroupConfig(name: 'Team Alpha').isLocked, isFalse);
      expect(const GroupConfig(name: 'A', password: '').isLocked, isFalse);
    });

    test('is locked when a password is set', () {
      expect(const GroupConfig(name: 'A', password: 'hunter2').isLocked, isTrue);
    });
  });

  group('MicState', () {
    test('defaults to unmuted and not transmitting', () {
      const s = MicState();

      expect(s.muted, isFalse);
      expect(s.transmitting, isFalse);
    });
  });
}
