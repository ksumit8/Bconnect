import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/state/discovered_groups_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  late FakeHub hub;
  late FakeTransport me;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 8, 26, 12);
    hub = FakeHub(clock: () => now);
    me = FakeTransport(hub, deviceId: 'me');
  });

  tearDown(() async => me.dispose());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(me),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<FakeTransport> advertise(
    String deviceId,
    String name, {
    int groupId = 0x1A2B,
    int memberCount = 1,
    bool isLocked = false,
    int rssi = -55,
  }) async {
    final host = FakeTransport(hub, deviceId: deviceId);
    addTearDown(host.dispose);
    await host.startAdvertising(
      groupName: name,
      groupId: groupId,
      memberCount: memberCount,
      isLocked: isLocked,
      isFull: false,
      rssi: rssi,
    );
    return host;
  }

  test('starts scanning when first watched', () async {
    final container = makeContainer();

    container.listen(discoveredGroupsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    expect(me.isScanning, isTrue);
  });

  test('stops scanning when disposed', () async {
    final container = makeContainer();

    final subscription =
        container.listen(discoveredGroupsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(me.isScanning, isFalse);
  });

  test('surfaces an advertising group', () async {
    await advertise('host1', 'Team Alpha', isLocked: true);
    final container = makeContainer();

    // FakeHub delivers scan results one event-loop turn after startScan(),
    // while the provider publishes its initial (empty) list synchronously
    // and eagerly at creation — that initial empty list is genuinely part
    // of the provider's contract (it drives the Discover screen's "scanning
    // for groups…" state). `.future` resolves with whatever the FIRST
    // emission is, which is that empty list, not the discovered group. So
    // rather than await `.future`, listen and let the deferred scan result
    // land before reading the settled state.
    container.listen(discoveredGroupsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final groups = container.read(discoveredGroupsProvider).value!;

    expect(groups.single.name, 'Team Alpha');
    expect(groups.single.isLocked, isTrue);
  });

  test('deduplicates repeated adverts from the same group', () async {
    final host = await advertise('host1', 'Team Alpha');
    final container = makeContainer();

    container.listen(discoveredGroupsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    await host.updateAdvertisement(memberCount: 4, isFull: false);
    await Future<void>.delayed(Duration.zero);

    final groups = container.read(discoveredGroupsProvider).value!;

    expect(groups.length, 1);
    expect(groups.single.memberCount, 4);
  });

  test('lists several groups sorted by descending signal strength', () async {
    // FakeHub previously hardcoded every advert's RSSI to -55, which made
    // this test unfalsifiable: with equal values, a non-increasing check
    // holds regardless of whether the provider sorts at all. Give the two
    // groups clearly different signal strengths so the assertion actually
    // exercises the sort.
    await advertise('host1', 'Team Alpha', groupId: 0x0001, rssi: -80);
    await advertise('host2', 'Project Beta', groupId: 0x0002, rssi: -50);
    final container = makeContainer();

    // Same reasoning as "surfaces an advertising group": both scan results
    // arrive a turn after creation, after the initial empty publish.
    container.listen(discoveredGroupsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final groups = container.read(discoveredGroupsProvider).value!;

    expect(groups.length, 2);
    expect(groups.first.name, 'Project Beta');
    expect(groups.first.rssi, -50);
    expect(groups.last.name, 'Team Alpha');
    expect(groups.last.rssi, -80);
    for (var i = 1; i < groups.length; i++) {
      expect(groups[i - 1].rssi, greaterThanOrEqualTo(groups[i].rssi));
    }
  });

  test('drops a group that has not advertised within the TTL', () async {
    await advertise('host1', 'Team Alpha', groupId: 0x0001);
    final container = makeContainer();

    container.listen(discoveredGroupsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(discoveredGroupsProvider).value!.length, 1);

    // Advance past the TTL, then let a second group advertise so the list
    // recomputes.
    now = now.add(ProtocolLimits.advertTtl + const Duration(seconds: 1));
    await advertise('host2', 'Project Beta', groupId: 0x0002);
    await Future<void>.delayed(Duration.zero);

    final groups = container.read(discoveredGroupsProvider).value!;

    expect(groups.length, 1);
    expect(groups.single.name, 'Project Beta');
  });

  test('keeps a group that keeps advertising', () async {
    final host = await advertise('host1', 'Team Alpha');
    final t0 = now;
    final container = makeContainer();

    container.listen(discoveredGroupsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    // Refresh just before the ORIGINAL advert would expire.
    now = t0.add(ProtocolLimits.advertTtl - const Duration(seconds: 1));
    await host.updateAdvertisement(memberCount: 2, isFull: false);
    await Future<void>.delayed(Duration.zero);

    // Now advance past the point the original (unrefreshed) advert's TTL
    // would have expired, but still within the TTL of the refresh above. A
    // regression that stopped resetting `lastSeen` on repeat adverts would
    // still pass a check made only up to `advertTtl - 1s` from t0 (the
    // previous version of this test) — go further to actually prove the
    // refresh extended the group's life. Trigger a second advertiser so the
    // list recomputes, exactly as in the TTL-expiry test above.
    now = now.add(const Duration(seconds: 2));
    expect(now.isAfter(t0.add(ProtocolLimits.advertTtl)), isTrue);
    await advertise('host2', 'Project Beta', groupId: 0x0002);
    await Future<void>.delayed(Duration.zero);

    final groups = container.read(discoveredGroupsProvider).value!;
    expect(groups.length, 2);
    expect(groups.map((g) => g.name), contains('Team Alpha'));
  });
}
