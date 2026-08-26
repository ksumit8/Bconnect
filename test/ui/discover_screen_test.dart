import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/domain/models/discovered_group.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/state/recent_groups_provider.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/ui/discover/widgets/group_tile.dart';

/// A transport whose [connect] doesn't resolve until [releaseConnect] is
/// called, so a test can pump execution up to the exact point where
/// `_join` is suspended awaiting the handshake, act (e.g. leave the
/// screen), and only then let it resume.
class _GatedConnectTransport extends FakeTransport {
  _GatedConnectTransport(super.hub, {required String deviceId})
      : super(deviceId: deviceId);

  final Completer<void> _gate = Completer<void>();

  void releaseConnect() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<String> connect(String deviceId) async {
    await _gate.future;
    return super.connect(deviceId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHub hub;
  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hub = FakeHub();
    transport = FakeTransport(hub, deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  /// Starts a real host session on its own transport, so the advertised
  /// group is genuinely joinable.
  Future<ProviderContainer> startHost(
    String name, {
    String? password,
    String deviceId = 'host',
  }) async {
    final hostTransport = FakeTransport(hub, deviceId: deviceId);
    addTearDown(hostTransport.dispose);

    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          GroupConfig(name: name, password: password),
          displayName: 'Host',
        );

    return hostContainer;
  }

  /// Advertises a full group directly over its own transport, bypassing
  /// `HostSession` (which would otherwise need `ProtocolLimits.maxMembers`
  /// real members to reach `isFull`), so a test can exercise the Discover
  /// screen's own "full groups aren't tappable" wiring against a
  /// genuinely-discovered `isFull` group.
  Future<void> advertiseFullGroup(String name, {String deviceId = 'full-host'}) async {
    final fullHostTransport = FakeTransport(hub, deviceId: deviceId);
    addTearDown(fullHostTransport.dispose);

    await fullHostTransport.startAdvertising(
      groupName: name,
      groupId: 0x0003,
      memberCount: ProtocolLimits.maxMembers,
      isLocked: false,
      isFull: true,
    );
  }

  /// The Discover screen's header runs a perpetual (indeterminate) spinner
  /// for as long as it's mounted, and `discoveredGroupsProvider` republishes
  /// on a 1-second prune timer even with nothing new to show — both keep
  /// scheduling frames forever, so `pumpAndSettle()` never converges while
  /// this screen is on screen (confirmed: a bare `CircularProgressIndicator`
  /// alone reproduces the same "pumpAndSettle timed out"). Pump a bounded,
  /// fixed number of frames instead: each step both flushes pending
  /// microtasks (async provider/session work) and elapses real time far
  /// enough to fire `FakeHub`'s deferred (Timer-based) scan-result delivery.
  Future<void> pumpBounded(WidgetTester tester, {int times = 30}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> openDiscover(WidgetTester tester, {FakeTransport? using}) async {
    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(using ?? transport)],
    );
    // Safety net only: `discoverTest` below disposes `container` explicitly
    // at the end of every test body. `addTearDown` callbacks run *after*
    // `TestWidgetsFlutterBinding`'s "no pending timers" invariant check, so
    // relying on it alone would leave that check tripping on
    // `discoveredGroupsProvider`'s still-live 1-second prune timer whenever
    // the Discover screen (or a route pushed on top of it) is still
    // mounted at the end of a test.
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: BconnectApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Existing Group'));
    await pumpBounded(tester);
  }

  /// Like `testWidgets`, but disposes the Discover screen's
  /// `ProviderContainer` before the test body returns so its still-running
  /// scan timer doesn't trip the "no pending timers" invariant (see
  /// `openDiscover`). `ProviderContainer.dispose()` is idempotent, so the
  /// `addTearDown` safety net calling it again afterwards is harmless.
  void discoverTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      await body(tester);
      container.dispose();
    });
  }

  discoverTest('shows the scanning header and a refresh control',
      (tester) async {
    await openDiscover(tester);

    expect(find.text('Join Group'), findsOneWidget);
    expect(find.text('Scanning for nearby groups...'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  discoverTest('starts scanning on the transport', (tester) async {
    await openDiscover(tester);

    expect(transport.isScanning, isTrue);
  });

  discoverTest('lists a nearby group with its member count', (tester) async {
    await startHost('Team Alpha');
    await openDiscover(tester);

    expect(find.text('Team Alpha'), findsOneWidget);
    expect(find.text('1 Member'), findsOneWidget);
  });

  testWidgets('pluralises the member count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupTile(
            group: DiscoveredGroup(
              groupId: '0001',
              deviceId: 'h',
              name: 'Project Beta',
              memberCount: 2,
              isLocked: false,
              isFull: false,
              rssi: -55,
              lastSeen: DateTime(2026, 8, 26),
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('2 Members'), findsOneWidget);
  });

  testWidgets('a full group renders as unavailable and ignores taps',
      (tester) async {
    var tapped = false;
    final group = DiscoveredGroup(
      groupId: '0002',
      deviceId: 'h',
      name: 'Full House',
      memberCount: 8,
      isLocked: false,
      isFull: true,
      rssi: -55,
      lastSeen: DateTime(2026, 8, 26),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupTile(
            group: group,
            // Mirrors DiscoverScreen's own
            // `g.isFull ? null : () => _join(...)` wiring.
            onTap: group.isFull ? null : () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('8 Members · Full'), findsOneWidget);

    await tester.tap(find.byType(GroupTile));
    await tester.pump();

    expect(tapped, isFalse);
  });

  discoverTest(
      "the Discover screen itself disables a full group's tile",
      (tester) async {
    await advertiseFullGroup('Full House');
    await openDiscover(tester);

    final tile = tester.widget<GroupTile>(find.byType(GroupTile));

    expect(tile.group.isFull, isTrue);
    // Proves the screen's own `g.isFull ? null : () => _join(...)` wiring,
    // not just `GroupTile`'s handling of a null callback in isolation.
    expect(tile.onTap, isNull);
    expect(find.text('8 Members · Full'), findsOneWidget);
  });

  discoverTest('shows a closed padlock for a password group', (tester) async {
    await startHost('Team Gamma', password: 'hunter2');
    await openDiscover(tester);

    final tile = tester.widget<GroupTile>(find.byType(GroupTile));

    expect(tile.group.isLocked, isTrue);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  discoverTest('shows an open padlock for an open group', (tester) async {
    await startHost('Open Group');
    await openDiscover(tester);

    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  discoverTest('tapping an open group joins it and opens the group screen',
      (tester) async {
    await startHost('Team Alpha');
    await openDiscover(tester);

    await tester.tap(find.text('Team Alpha'));
    await pumpBounded(tester);

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.groupName, 'Team Alpha');
    expect(state.isHost, isFalse);

    // A successful join must also land in the recent-groups list, or a
    // returning user would never see it on the home screen.
    final recent = container.read(recentGroupsProvider).value;
    expect(recent, isNotNull);
    expect(recent!.any((g) => g.name == 'Team Alpha'), isTrue);
  });

  discoverTest(
      'shows an error and returns to idle when the join fails',
      (tester) async {
    final hostContainer = await startHost('Team Alpha');
    await openDiscover(tester);

    // The host goes away between being discovered and being joined (moved
    // out of range, Bluetooth toggled off, etc.), so the connect the tap
    // triggers fails. `ClientSession.join` catches that internally and
    // resolves to `SessionFailed` rather than throwing.
    //
    // Disposing the host's transport closes a `StreamController` with an
    // active listener (`HostSession`'s own subscription); delivering the
    // resulting "done" event — and the join failure the tap below then
    // triggers — depends on microtasks that flutter_test's fake-async test
    // zone never flushes without a real event-loop turn (the same quirk
    // `create_group_screen_test.dart` documents next to its own `runAsync`
    // call for `StreamSubscription.cancel()`; confirmed here too: this
    // hung indefinitely under plain awaits before switching to
    // `runAsync`). Run the disposal, the tap it enables, and the resulting
    // async fallout for real.
    await tester.runAsync(() async {
      await hostContainer.read(transportProvider).dispose();
      await tester.tap(find.text('Team Alpha'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    // Not `pumpAndSettle()`: the Discover screen's perpetual spinner and
    // prune timer never let it converge (see `pumpBounded`'s doc above).
    await pumpBounded(tester);

    expect(find.text('Could not join the group'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  discoverTest(
      'leaving mid-join does not crash once the join later resolves',
      (tester) async {
    await startHost('Team Alpha');

    final gated = _GatedConnectTransport(hub, deviceId: 'gated-me');
    addTearDown(gated.dispose);

    await openDiscover(tester, using: gated);

    await tester.tap(find.text('Team Alpha'));
    // Advance far enough for `_join` to reach the gated `connect()` call
    // and suspend there — it cannot resolve until `releaseConnect()` is
    // called below, so there's no risk of running past it.
    await pumpBounded(tester, times: 5);

    // Leave the Discover screen while the join is still in flight. This
    // unmounts the widget and disposes `discoveredGroupsProvider`.
    await tester.pageBack();
    await pumpBounded(tester);

    // Now let the handshake complete, resuming `_join` after the screen
    // (and the `BuildContext`/`WidgetRef` it captured) is gone.
    gated.releaseConnect();
    await pumpBounded(tester);

    expect(tester.takeException(), isNull);
  });

  discoverTest('tapping a locked group does not join it directly',
      (tester) async {
    await startHost('Team Gamma', password: 'hunter2');
    await openDiscover(tester);

    await tester.tap(find.text('Team Gamma'));
    await pumpBounded(tester);

    // Navigated to /join rather than joining. `/join` is pushed (not a
    // replace), so the Discover screen — and its GroupTile list — remains
    // in the widget tree underneath for state preservation; assert it's no
    // longer the visible, interactive screen instead of asserting it's
    // gone entirely. Task 17 asserts on the pushed screen's own content.
    expect(container.read(sessionProvider), isA<SessionIdle>());
    expect(find.byType(GroupTile).hitTestable(), findsNothing);
  });

  discoverTest('lists several groups at once', (tester) async {
    await startHost('Team Alpha', deviceId: 'h1');
    await startHost('Project Beta', deviceId: 'h2');
    await openDiscover(tester);

    expect(find.byType(GroupTile), findsNWidgets(2));
  });

  discoverTest('stops scanning when the screen is closed', (tester) async {
    await openDiscover(tester);
    expect(transport.isScanning, isTrue);

    await tester.pageBack();
    await pumpBounded(tester);

    expect(transport.isScanning, isFalse);
  });
}
