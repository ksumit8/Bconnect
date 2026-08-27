import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHub hub;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hub = FakeHub();
  });

  /// The Discover screen runs a perpetual spinner and a 1-second prune timer
  /// for as long as it's mounted, so `pumpAndSettle()` never converges while
  /// it (or a route pushed on top of it) is on screen — see
  /// `discover_screen_test.dart`'s `pumpBounded` doc for the full
  /// explanation. Pump a bounded, fixed number of frames instead.
  Future<void> pumpBounded(WidgetTester tester, {int times = 30}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('create a password group, then a second device joins it',
      (tester) async {
    // Device A drives the UI.
    final aTransport = FakeTransport(hub, deviceId: 'a');
    addTearDown(aTransport.dispose);
    final aContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(aTransport)],
    );
    addTearDown(aContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: aContainer,
        // A fresh router per test: the process-wide `appRouter` singleton
        // remembers its current location across tests, so reusing it here
        // would leak navigation from one test into the next.
        child: BconnectApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    // Home -> Create.
    expect(find.text('Group Talk'), findsOneWidget);
    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();

    // Fill in a password-protected group.
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tester.tap(find.text('Password Protected'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter password'),
      'hunter2',
    );
    // The Create Group button sits below the fold of the form's ListView at
    // the default test surface size, so it isn't built (and find.text finds
    // nothing) until scrolled into view.
    await tester.ensureVisible(
      find.text('Create Group', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    // Now hosting.
    expect(find.text('Group is Active'), findsOneWidget);
    expect(find.text('You (Admin)'), findsOneWidget);
    expect(find.text('1 Member'), findsOneWidget);

    // Device B joins headlessly.
    final bTransport = FakeTransport(hub, deviceId: 'b');
    addTearDown(bTransport.dispose);
    final bContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(bTransport)],
    );
    addTearDown(bContainer.dispose);

    final found = bTransport.events.whereType<ScanResultEvent>().first;
    await bTransport.startScan();
    // FakeHub.deliverCurrentAdverts defers delivery to the next event-loop
    // turn via a real Timer. Widget tests run on a fake clock that only
    // fires pending real Timers once it's elapsed by a positive duration —
    // pump(Duration.zero) (the default) does not do it.
    await tester.pump(const Duration(milliseconds: 10));
    final group = (await found).group;

    expect(group.name, 'Team Alpha');
    expect(group.isLocked, isTrue);

    await bContainer.read(sessionProvider.notifier).joinGroup(
          group,
          password: 'hunter2',
          displayName: 'Device 1',
        );
    await tester.pumpAndSettle();

    // Device A's roster updated live.
    expect(find.text('Device 1'), findsOneWidget);
    expect(find.text('2 Members'), findsOneWidget);

    // Talk, then release.
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Tap to Speak')));
    await tester.pumpAndSettle();
    expect(aTransport.isTalking, isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(aTransport.isTalking, isFalse);

    // Route audio to the earpiece and come back.
    await tester.tap(find.text('Speaker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Earpiece'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The call survived the detour.
    expect(find.text('Group is Active'), findsOneWidget);

    // End the call. SessionController.leave() awaits _teardown()'s broadcast
    // StreamSubscription.cancel(), which does not resolve under
    // flutter_test's fake-async zone with a bare pump (see
    // `join_password_screen_test.dart`'s retry test and
    // `group_screen_test.dart`'s "End Call" test for the documented
    // reference pattern). Interleave `tester.pump()` with a short real-time
    // delay instead, polling until the session settles, bounded so a
    // regression fails rather than hangs.
    final endCallButton = find.text('End Call');
    await tester.runAsync(() async {
      await tester.tap(endCallButton);
      for (var i = 0; i < 100; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (aContainer.read(sessionProvider) is SessionIdle) break;
      }
      // Reaching SessionIdle doesn't mean the widget has finished reacting
      // to it yet (navigating home) — pump a further bounded run so that
      // trailing work settles too.
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('Group Talk'), findsOneWidget);
    expect(aContainer.read(sessionProvider), isA<SessionIdle>());

    // Device B saw the group end.
    expect(
      (bContainer.read(sessionProvider) as SessionFailed).error,
      SessionError.hostLeft,
    );

    // The group is now in Your Groups.
    expect(find.text('Team Alpha'), findsOneWidget);
  });

  testWidgets('a wrong password keeps the user on the password screen',
      (tester) async {
    // Host headlessly.
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);
    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Gamma', password: 'correct'),
          displayName: 'Host',
        );

    // Join through the UI.
    final transport = FakeTransport(hub, deviceId: 'me');
    addTearDown(transport.dispose);
    final container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: BconnectApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    // The Discover screen this pushes has a perpetual spinner and prune
    // timer, so `pumpAndSettle()` never converges while it (or /join, pushed
    // on top of it) is mounted — use the bounded pump instead.
    await tester.tap(find.text('Join Existing Group'));
    await pumpBounded(tester);
    await tester.tap(find.text('Team Gamma'));
    await pumpBounded(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Password'),
      'wrong',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await pumpBounded(tester);

    expect(find.text('Incorrect password'), findsOneWidget);

    // Correcting it succeeds. This retry runs SessionController.joinGroup()
    // again, which tears down the failed ClientSession before starting the
    // new one — the same broadcast StreamSubscription.cancel() stall as End
    // Call (see `join_password_screen_test.dart`'s retry test for the
    // documented reference pattern). Interleave `tester.pump()` with a short
    // real-time delay, bounded so a regression fails rather than hangs.
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Password'),
      'correct',
    );
    final joinButton = find.widgetWithText(FilledButton, 'Join Group');
    await tester.runAsync(() async {
      await tester.tap(joinButton);
      for (var i = 0; i < 100; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (container.read(sessionProvider) is SessionConnected) break;
      }
      // Reaching SessionConnected doesn't mean the widget has finished
      // reacting to it yet (recording the recent group, then navigating to
      // /group) — pump a further bounded run so that trailing work settles
      // too.
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await pumpBounded(tester);

    expect(find.text('Group is Active'), findsOneWidget);

    // discoveredGroupsProvider (watched by the now-unmounted Discover
    // screen) is autoDispose, but its 1-second prune Timer isn't guaranteed
    // to have been cancelled yet just because navigation reached /group —
    // see join_password_screen_test.dart's `joinTest` wrapper, which
    // disposes its container explicitly for exactly this reason. Do the
    // same here, before the test body returns: `addTearDown` runs after
    // the binding's "no pending timers" invariant check, too late to avoid
    // tripping it. `ProviderContainer.dispose()` is idempotent, so the
    // `addTearDown` safety net calling it again afterwards is harmless.
    container.dispose();
  });
}
