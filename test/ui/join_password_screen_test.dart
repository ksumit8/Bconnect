import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/recent_groups_provider.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/ui/join/join_password_screen.dart';

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

  /// The Discover screen underneath `/join` runs a perpetual spinner and a
  /// 1-second prune timer for as long as it's mounted, so `pumpAndSettle()`
  /// never converges once `/join` is pushed on top of it (see
  /// `discover_screen_test.dart`'s `pumpBounded` doc for the full
  /// explanation). Pump a bounded, fixed number of frames instead.
  Future<void> pumpBounded(WidgetTester tester, {int times = 30}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Opens the password screen by driving the real discover flow, so the
  /// `DiscoveredGroup` the screen receives as `extra` is genuine.
  Future<void> openJoinScreen(WidgetTester tester) async {
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);
    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha', password: 'hunter2'),
          displayName: 'Host',
        );

    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    // Safety net only: `joinTest` below disposes `container` explicitly at
    // the end of every test body, before `TestWidgetsFlutterBinding`'s "no
    // pending timers" invariant check runs (see `discover_screen_test.dart`).
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
    await tester.tap(find.text('Team Alpha'));
    await pumpBounded(tester);
  }

  /// Like `testWidgets`, but disposes the pushed screens' `ProviderContainer`
  /// before the test body returns so the Discover screen's still-running
  /// scan timer underneath `/join` doesn't trip the "no pending timers"
  /// invariant. `ProviderContainer.dispose()` is idempotent, so the
  /// `addTearDown` safety net calling it again afterwards is harmless.
  void joinTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      await body(tester);
      container.dispose();
    });
  }

  joinTest('shows the group name and the protected notice', (tester) async {
    await openJoinScreen(tester);

    final screen = find.byType(JoinPasswordScreen);
    expect(
      find.descendant(of: screen, matching: find.text('Team Alpha')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: screen,
        matching: find.text('This group is password protected'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: screen, matching: find.text('Enter Password')),
      findsWidgets,
    );
    expect(
      find.descendant(of: screen, matching: find.text('Join Group')),
      findsWidgets,
    );
    expect(
      find.descendant(of: screen, matching: find.text('Cancel')),
      findsOneWidget,
    );
  });

  joinTest('obscures the password until the reveal is tapped',
      (tester) async {
    await openJoinScreen(tester);

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Enter Password'))
          .obscureText,
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.visibility));
    await pumpBounded(tester, times: 2);

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Enter Password'))
          .obscureText,
      isFalse,
    );
  });

  joinTest('refuses an empty password', (tester) async {
    await openJoinScreen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await pumpBounded(tester);

    expect(find.text('Enter a password'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  joinTest('joins with the correct password', (tester) async {
    await openJoinScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Password'),
      'hunter2',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
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

  joinTest('stays on the screen and explains a wrong password',
      (tester) async {
    await openJoinScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Password'),
      'wrong',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await pumpBounded(tester);

    expect(find.text('Incorrect password'), findsOneWidget);
    expect(find.text('This group is password protected'), findsOneWidget);
    // The session must not be left parked in a failed state, or Task 18's
    // group screen (which reacts to SessionFailed) would misfire on this
    // stale failure the next time it's watched.
    expect(container.read(sessionProvider), isA<SessionIdle>());

    // The password field and Join button must still be interactive (not
    // stuck in the busy state) so the user can correct the password and
    // retry without leaving the screen.
    expect(
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Join Group'),
      ).onPressed,
      isNotNull,
    );

    final passwordField = find.widgetWithText(TextField, 'Enter Password');
    await tester.enterText(passwordField, 'hunter2');
    await tester.pump();

    expect(
      tester.widget<TextField>(passwordField).controller?.text,
      'hunter2',
    );

    // Retrying end-to-end: SessionController.joinGroup() tears down the
    // failed ClientSession before starting the new one, which cancels that
    // client's subscription to the transport's event stream. That
    // cancellation's completion is gated on the binding processing a
    // frame, not on wall-clock time — a bare `Future.delayed` inside
    // `runAsync` (the pattern `create_group_screen_test.dart` and
    // `discover_screen_test.dart` use for other async-teardown cases) lets
    // real time pass without ever pumping a frame, so the cancel's
    // continuation never runs and the retry hangs indefinitely. Interleave
    // `tester.pump()` with the real-time delay instead, so each tick both
    // advances the binding and gives the real event loop a turn. This is
    // the reference pattern for that combination; reach for it again
    // anywhere else a retry crosses a second `_teardown()` (Tasks 18/20
    // are likely candidates).
    final joinButton = find.widgetWithText(FilledButton, 'Join Group');
    await tester.runAsync(() async {
      await tester.tap(joinButton);
      for (var i = 0; i < 100; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (container.read(sessionProvider) is SessionConnected) break;
      }
      // The session reaching SessionConnected doesn't mean the widget has
      // finished reacting to it yet (navigating to /group, and the
      // recentGroupsProvider.record() persist that happens first) — pump a
      // further bounded run so that trailing work settles too.
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    // Reaching /group also unmounts the Discover screen underneath, whose
    // `discoveredGroupsProvider` stops the still-active scan on dispose;
    // let that settle on the fake clock too, or a scan-result broadcast
    // scheduled just before navigation can trip the "no pending timers"
    // invariant after the test body returns.
    await pumpBounded(tester);

    final state = container.read(sessionProvider) as SessionConnected;
    expect(state.groupName, 'Team Alpha');
    expect(state.isHost, isFalse);

    final recent = container.read(recentGroupsProvider).value;
    expect(recent, isNotNull);
    expect(recent!.any((g) => g.name == 'Team Alpha'), isTrue);
  });

  joinTest('cancel returns to the group list', (tester) async {
    await openJoinScreen(tester);

    await tester.tap(find.text('Cancel'));
    await pumpBounded(tester);

    expect(find.text('Scanning for nearby groups...'), findsOneWidget);
  });
}
