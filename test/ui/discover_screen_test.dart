import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/domain/models/discovered_group.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/ui/discover/widgets/group_tile.dart';

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

  Future<void> openDiscover(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
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
