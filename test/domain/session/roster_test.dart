import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/member.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/domain/session/roster.dart';

void main() {
  const host = Member(id: 'm1', displayName: 'You', isHost: true, isSelf: true);
  const one = Member(id: 'm2', displayName: 'Device 1');
  const two = Member(id: 'm3', displayName: 'Device 2');

  group('add', () {
    test('appends a new member', () {
      expect(Roster.add(const [host], one), const [host, one]);
    });

    test('replaces an existing member with the same id', () {
      final result = Roster.add(
        const [host, one],
        const Member(id: 'm2', displayName: 'Renamed'),
      );

      expect(result.length, 2);
      expect(result[1].displayName, 'Renamed');
    });

    test('does not mutate the input list', () {
      const input = [host];
      Roster.add(input, one);

      expect(input, const [host]);
    });
  });

  group('remove', () {
    test('drops the matching member', () {
      expect(Roster.remove(const [host, one], 'm2'), const [host]);
    });

    test('is a no-op for an unknown id', () {
      expect(Roster.remove(const [host], 'nope'), const [host]);
    });
  });

  group('setTalking', () {
    test('marks only the named member', () {
      final result = Roster.setTalking(const [host, one], 'm2', true);

      expect(result[0].isTalking, isFalse);
      expect(result[1].isTalking, isTrue);
    });

    test('clears the flag again', () {
      var result = Roster.setTalking(const [host, one], 'm2', true);
      result = Roster.setTalking(result, 'm2', false);

      expect(result[1].isTalking, isFalse);
    });
  });

  group('setPresence', () {
    test('updates only the named member', () {
      final result =
          Roster.setPresence(const [host, one], 'm2', MemberPresence.reconnecting);

      expect(result[0].presence, MemberPresence.online);
      expect(result[1].presence, MemberPresence.reconnecting);
    });
  });

  group('talkingCount', () {
    test('counts members currently talking', () {
      var r = Roster.setTalking(const [host, one, two], 'm2', true);
      r = Roster.setTalking(r, 'm3', true);

      expect(Roster.talkingCount(r), 2);
    });
  });

  group('isFull', () {
    test('is false below the maximum', () {
      final r = List.generate(
        ProtocolLimits.maxMembers - 1,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );

      expect(Roster.isFull(r), isFalse);
    });

    test('is true at the maximum', () {
      final r = List.generate(
        ProtocolLimits.maxMembers,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );

      expect(Roster.isFull(r), isTrue);
    });
  });

  group('canTalk', () {
    test('allows a talker below the concurrent cap', () {
      final r = List.generate(
        ProtocolLimits.maxMembers,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );
      var withTalkers = Roster.setTalking(r, '0', true);
      withTalkers = Roster.setTalking(withTalkers, '1', true);

      expect(Roster.canTalk(withTalkers, '2'), isTrue);
    });

    test('refuses a talker once the concurrent cap is reached', () {
      final r = List.generate(
        ProtocolLimits.maxMembers,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );
      var withTalkers = r;
      for (var i = 0; i < ProtocolLimits.maxConcurrentTalkers; i++) {
        withTalkers = Roster.setTalking(withTalkers, '$i', true);
      }

      expect(Roster.canTalk(withTalkers, '7'), isFalse);
    });

    test('always allows a member who is already talking', () {
      final r = List.generate(
        ProtocolLimits.maxMembers,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );
      var withTalkers = r;
      for (var i = 0; i < ProtocolLimits.maxConcurrentTalkers; i++) {
        withTalkers = Roster.setTalking(withTalkers, '$i', true);
      }

      expect(Roster.canTalk(withTalkers, '0'), isTrue);
    });
  });
}
