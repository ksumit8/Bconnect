import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/mic_provider.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

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
  /// never converges once it's on screen (see
  /// `discover_screen_test.dart`'s `pumpBounded` doc for the full
  /// explanation). Pump a bounded, fixed number of frames instead.
  Future<void> pumpBounded(WidgetTester tester, {int times = 30}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Creates a group through the real UI so the screen renders live state.
  Future<void> hostAGroup(WidgetTester tester) async {
    container = ProviderContainer(
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

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    // The Create Group button sits below the fold of the form's ListView,
    // so it isn't built (and find.text finds nothing) until scrolled into
    // view — see create_group_screen_test.dart's tapCreateButton helper.
    await tester.ensureVisible(
      find.text('Create Group', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the group name, status, and controls', (tester) async {
    await hostAGroup(tester);

    expect(find.text('Team Alpha'), findsOneWidget);
    expect(find.text('Group is Active'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);
    expect(find.text('Tap to Speak'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('End Call'), findsOneWidget);
  });

  testWidgets('labels the host as You (Admin)', (tester) async {
    await hostAGroup(tester);

    expect(find.text('You (Admin)'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('shows the member count badge', (tester) async {
    await hostAGroup(tester);

    expect(find.text('1 Member'), findsOneWidget);
  });

  testWidgets('lists a member that joins', (tester) async {
    await hostAGroup(tester);

    final other = FakeTransport(hub, deviceId: 'other');
    addTearDown(other.dispose);
    final otherContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(other)],
    );
    addTearDown(otherContainer.dispose);

    final found = other.events.whereType<ScanResultEvent>().first;
    await other.startScan();
    // FakeHub.deliverCurrentAdverts defers delivery to the next event-loop
    // turn via a real Timer. Widget tests run on a fake clock that only
    // fires pending real Timers once it's elapsed by a positive duration —
    // pump(Duration.zero) (the default) does not do it (see
    // create_group_screen_test.dart's scanIsLocked helper).
    await tester.pump(const Duration(milliseconds: 10));

    await otherContainer.read(sessionProvider.notifier).joinGroup(
          (await found).group,
          displayName: 'Device 1',
        );
    await tester.pumpAndSettle();

    expect(find.text('Device 1'), findsOneWidget);
    expect(find.text('2 Members'), findsOneWidget);
  });

  testWidgets('holding the talk button transmits, releasing stops',
      (tester) async {
    await hostAGroup(tester);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Tap to Speak')));
    await tester.pumpAndSettle();

    expect(transport.isTalking, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(transport.isTalking, isFalse);
  });

  testWidgets('the mute button toggles the mic', (tester) async {
    await hostAGroup(tester);

    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();

    expect(container.read(micProvider).muted, isTrue);
    expect(transport.micEnabled, isFalse);

    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();

    expect(container.read(micProvider).muted, isFalse);
  });

  testWidgets('a muted mic refuses to transmit', (tester) async {
    await hostAGroup(tester);

    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Tap to Speak')));
    await tester.pumpAndSettle();

    expect(transport.isTalking, isFalse);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the speaker button opens the audio output screen',
      (tester) async {
    await hostAGroup(tester);

    await tester.tap(find.text('Speaker'));
    await tester.pumpAndSettle();

    expect(find.text('Audio Output'), findsWidgets);
  });

  testWidgets('End Call leaves the group and returns home', (tester) async {
    await hostAGroup(tester);

    // End Call runs SessionController.leave(), which awaits _teardown()'s
    // broadcast StreamSubscription.cancel(). That cancellation's completion
    // is gated on the binding processing a frame, not on wall-clock time —
    // a bare `pumpAndSettle()` never lets it resolve under flutter_test's
    // fake-async zone (see join_password_screen_test.dart's retry test for
    // the documented reference pattern and explanation). Interleave
    // `tester.pump()` with a short real-time delay instead, polling until
    // the session reaches SessionIdle, with a bounded loop so a regression
    // fails rather than hangs.
    final endCallButton = find.text('End Call');
    await tester.runAsync(() async {
      await tester.tap(endCallButton);
      for (var i = 0; i < 100; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (container.read(sessionProvider) is SessionIdle) break;
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

    expect(container.read(sessionProvider), isA<SessionIdle>());
    expect(find.text('Group Talk'), findsOneWidget);
  });

  testWidgets(
      'End Call as a client leaves cleanly with no spurious snackbar',
      (tester) async {
    // This device is a client; it taps End Call itself. FakeHub.disconnect
    // delivers PeerDisconnectedEvent to both ends, so ClientSession's
    // `_leaving` flag is the only thing distinguishing "I chose to leave"
    // from "the connection dropped" — if that guard regressed, this client
    // would see a spurious connectionLost/hostLeft snackbar instead of a
    // clean return home.
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);
    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha'),
          displayName: 'Host',
        );

    container = ProviderContainer(
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
    // timer, so `pumpAndSettle()` never converges while it's mounted — use
    // the bounded pump instead (see `pumpBounded`'s doc above).
    await tester.tap(find.text('Join Existing Group'));
    await pumpBounded(tester);
    await tester.tap(find.text('Team Alpha'));
    await pumpBounded(tester);

    expect(find.text('Group is Active'), findsOneWidget);

    // End Call runs SessionController.leave(), which awaits _teardown()'s
    // broadcast StreamSubscription.cancel() — the same fake-async stall as
    // the host End Call test above. Interleave `tester.pump()` with a short
    // real-time delay, bounded so a regression fails rather than hangs.
    final endCallButton = find.text('End Call');
    await tester.runAsync(() async {
      await tester.tap(endCallButton);
      for (var i = 0; i < 100; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (container.read(sessionProvider) is SessionIdle) break;
      }
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(container.read(sessionProvider), isA<SessionIdle>());
    expect(find.text('Group Talk'), findsOneWidget);
    expect(find.textContaining('Connection lost'), findsNothing);
    expect(find.textContaining('Group ended by host'), findsNothing);
  });

  testWidgets('returns home when the host ends the group', (tester) async {
    // This device is a client; the host tears the group down underneath it.
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);
    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha'),
          displayName: 'Host',
        );

    container = ProviderContainer(
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
    // timer, so `pumpAndSettle()` never converges while it's mounted — use
    // the bounded pump instead (see `pumpBounded`'s doc above).
    await tester.tap(find.text('Join Existing Group'));
    await pumpBounded(tester);
    await tester.tap(find.text('Team Alpha'));
    await pumpBounded(tester);

    expect(find.text('Group is Active'), findsOneWidget);

    // Tearing down the host's session runs SessionController._teardown(),
    // which awaits a broadcast StreamSubscription.cancel() that does not
    // resolve under fake-async with a bare pump (see the End Call test
    // above, and join_password_screen_test.dart's retry test, for the
    // documented reference pattern). Interleave `tester.pump()` with a
    // short real-time delay, polling until the client has reacted
    // (navigated home), bounded so a regression fails instead of hanging.
    await tester.runAsync(() async {
      await hostContainer.read(sessionProvider.notifier).leave();
      for (var i = 0; i < 100; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (find.text('Group Talk').evaluate().isNotEmpty) break;
      }
      // Reaching home doesn't mean the SnackBar's entrance (Hero) animation
      // has finished — pump a further bounded run so it settles before
      // asserting on its content, or the transient mid-flight frame shows
      // the text twice.
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(find.text('Group Talk'), findsOneWidget);
    expect(find.text('Group ended by host'), findsOneWidget);
    // The failure must actually be consumed via reset(), or the client's
    // sessionProvider would stay stuck in SessionFailed forever — the
    // snackbar and navigation above fire independently of whether reset()
    // ran, so this is the only assertion that catches that regression.
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });
}
