import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/domain/models/audio.dart';
import 'package:bconnect/domain/models/recent_group.dart';
import 'package:bconnect/state/audio_route_provider.dart';
import 'package:bconnect/state/display_name_provider.dart';
import 'package:bconnect/state/mic_provider.dart';
import 'package:bconnect/state/recent_groups_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;
  late ProviderContainer container;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 8, 26, 12);
    transport = FakeTransport(FakeHub(), deviceId: 'me');
    container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(transport),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await transport.dispose();
  });

  group('micProvider', () {
    test('starts unmuted and not transmitting', () {
      final state = container.read(micProvider);

      expect(state.muted, isFalse);
      expect(state.transmitting, isFalse);
    });

    test('muting disables the mic on the transport', () async {
      await container.read(micProvider.notifier).setMuted(true);

      expect(container.read(micProvider).muted, isTrue);
      expect(transport.micEnabled, isFalse);
    });

    test('toggleMute flips the state both ways', () async {
      final notifier = container.read(micProvider.notifier);

      await notifier.toggleMute();
      expect(container.read(micProvider).muted, isTrue);

      await notifier.toggleMute();
      expect(container.read(micProvider).muted, isFalse);
      expect(transport.micEnabled, isTrue);
    });

    test('muting while transmitting also stops transmitting', () async {
      final notifier = container.read(micProvider.notifier);
      notifier.setTransmitting(true);

      await notifier.setMuted(true);

      expect(container.read(micProvider).transmitting, isFalse);
    });
  });

  group('audioRouteProvider', () {
    test('defaults to the speaker', () {
      expect(container.read(audioRouteProvider), AudioRoute.speaker);
    });

    test('switching to the earpiece reaches the transport', () async {
      await container
          .read(audioRouteProvider.notifier)
          .setRoute(AudioRoute.earpiece);

      expect(container.read(audioRouteProvider), AudioRoute.earpiece);
      expect(transport.audioRoute, AudioRoute.earpiece);
    });
  });

  group('displayNameProvider', () {
    test('defaults when nothing is stored', () async {
      expect(
        await container.read(displayNameProvider.future),
        kDefaultDisplayName,
      );
    });

    test('persists a new name', () async {
      await container.read(displayNameProvider.future);
      await container.read(displayNameProvider.notifier).setName('Atharva');

      expect(container.read(displayNameProvider).value, 'Atharva');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('display_name'), 'Atharva');
    });

    test('reloads a stored name', () async {
      SharedPreferences.setMockInitialValues({'display_name': 'Stored'});

      final fresh = ProviderContainer(
        overrides: [transportProvider.overrideWithValue(transport)],
      );
      addTearDown(fresh.dispose);

      expect(await fresh.read(displayNameProvider.future), 'Stored');
    });

    test('ignores an all-whitespace name', () async {
      await container.read(displayNameProvider.future);
      await container.read(displayNameProvider.notifier).setName('   ');

      expect(container.read(displayNameProvider).value, kDefaultDisplayName);
    });
  });

  group('recentGroupsProvider', () {
    test('starts empty', () async {
      expect(await container.read(recentGroupsProvider.future), isEmpty);
    });

    test('records a group', () async {
      await container.read(recentGroupsProvider.future);
      await container.read(recentGroupsProvider.notifier).record(
            groupId: '1a2b',
            name: 'Team Alpha',
            memberCount: 3,
          );

      final groups = container.read(recentGroupsProvider).value!;

      expect(groups.single.name, 'Team Alpha');
      expect(groups.single.memberCount, 3);
      expect(groups.single.lastJoined, now);
    });

    test('moves a repeated group to the front without duplicating it',
        () async {
      final notifier = container.read(recentGroupsProvider.notifier);
      await container.read(recentGroupsProvider.future);

      await notifier.record(groupId: 'a', name: 'A', memberCount: 1);
      await notifier.record(groupId: 'b', name: 'B', memberCount: 1);
      await notifier.record(groupId: 'a', name: 'A', memberCount: 5);

      final groups = container.read(recentGroupsProvider).value!;

      expect(groups.length, 2);
      expect(groups.first.groupId, 'a');
      expect(groups.first.memberCount, 5);
    });

    test('keeps at most five groups', () async {
      final notifier = container.read(recentGroupsProvider.notifier);
      await container.read(recentGroupsProvider.future);

      for (var i = 0; i < 7; i++) {
        await notifier.record(groupId: 'g$i', name: 'G$i', memberCount: 1);
      }

      final groups = container.read(recentGroupsProvider).value!;

      expect(groups.map((g) => g.groupId).toList(), [
        'g6',
        'g5',
        'g4',
        'g3',
        'g2',
      ]);
    });

    test('record before the initial load resolves does not clobber '
        'persisted groups', () async {
      SharedPreferences.setMockInitialValues({
        'recent_groups': [
          jsonEncode(
            RecentGroup(
              groupId: 'old',
              name: 'Old Group',
              memberCount: 2,
              lastJoined: now,
            ).toJson(),
          ),
        ],
      });

      final fresh = ProviderContainer(
        overrides: [
          transportProvider.overrideWithValue(transport),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(fresh.dispose);

      // Deliberately do NOT await recentGroupsProvider.future first: this is
      // the exact race the fix guards against.
      await fresh.read(recentGroupsProvider.notifier).record(
            groupId: 'new',
            name: 'New Group',
            memberCount: 1,
          );

      final groups = await fresh.read(recentGroupsProvider.future);

      expect(groups.map((g) => g.groupId).toList(), ['new', 'old']);
    });

    test('survives a reload', () async {
      await container.read(recentGroupsProvider.future);
      await container.read(recentGroupsProvider.notifier).record(
            groupId: '1a2b',
            name: 'Team Alpha',
            memberCount: 3,
          );

      final fresh = ProviderContainer(
        overrides: [transportProvider.overrideWithValue(transport)],
      );
      addTearDown(fresh.dispose);

      final groups = await fresh.read(recentGroupsProvider.future);

      expect(groups.single.name, 'Team Alpha');
    });

    test('clear empties the list', () async {
      final notifier = container.read(recentGroupsProvider.notifier);
      await container.read(recentGroupsProvider.future);
      await notifier.record(groupId: 'a', name: 'A', memberCount: 1);

      await notifier.clear();

      expect(container.read(recentGroupsProvider).value, isEmpty);
    });
  });
}
