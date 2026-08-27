import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/domain/models/audio.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/state/audio_route_provider.dart';
import 'package:bconnect/state/display_name_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/ui/audio/audio_output_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    transport = FakeTransport(FakeHub(), deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  Future<void> pumpApp(WidgetTester tester, {Object? peripheralError}) async {
    container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(transport),
        if (peripheralError != null)
          // Riverpod's automatic retry is disabled on this provider
          // (`retry: (_, __) => null`) precisely so this AsyncError is
          // reachable in tests rather than staying stuck in AsyncLoading
          // through the default retry backoff.
          peripheralSupportedProvider.overrideWith(
            (ref) async => throw peripheralError,
          ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // A fresh router per test: appRouter is a process-wide singleton
        // that remembers its current location across pumpWidget calls in
        // the same test file, so reusing it here would leak navigation
        // from one test into the next.
        child: BconnectApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAudioScreen(WidgetTester tester) async {
    await pumpApp(tester);

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

    await tester.tap(find.text('Speaker'));
    await tester.pumpAndSettle();
  }

  group('audio output', () {
    // Note: a pushed route leaves the group screen in the widget tree
    // beneath it, so `find.text('Speaker')` can match twice. Scope finders
    // with `find.descendant(of: find.byType(AudioOutputScreen), ...)`
    // wherever a label appears on both screens.

    testWidgets('lists both routes and the explanatory note', (tester) async {
      await openAudioScreen(tester);

      expect(find.text('Audio Output'), findsWidgets);
      expect(find.text('Earpiece'), findsOneWidget);
      expect(
        find.text('Use Speaker for group communication'),
        findsOneWidget,
      );
      expect(find.text('Use Earpiece for private listening'), findsOneWidget);
    });

    testWidgets('starts on the speaker', (tester) async {
      await openAudioScreen(tester);

      expect(container.read(audioRouteProvider), AudioRoute.speaker);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('switching to the earpiece reaches the transport',
        (tester) async {
      await openAudioScreen(tester);

      await tester.tap(find.text('Earpiece'));
      await tester.pumpAndSettle();

      expect(container.read(audioRouteProvider), AudioRoute.earpiece);
      expect(transport.audioRoute, AudioRoute.earpiece);
    });

    testWidgets('switching back to the speaker works', (tester) async {
      await openAudioScreen(tester);

      await tester.tap(find.text('Earpiece'));
      await tester.pumpAndSettle();

      // The group screen is still in the tree beneath this route and also has
      // a "Speaker" label, so scope the finder to this screen's option.
      await tester.tap(
        find.descendant(
          of: find.byType(AudioOutputScreen),
          matching: find.text('Speaker'),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(audioRouteProvider), AudioRoute.speaker);
    });

    testWidgets('the call survives visiting this screen', (tester) async {
      await openAudioScreen(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // sessionProvider is not autoDispose (spec section 6.2).
      expect(find.text('Group is Active'), findsOneWidget);
    });
  });

  group('settings', () {
    Future<void> openSettings(
      WidgetTester tester, {
      Object? peripheralError,
    }) async {
      await pumpApp(tester, peripheralError: peripheralError);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current display name', (tester) async {
      await openSettings(tester);

      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text(kDefaultDisplayName), findsWidgets);
    });

    testWidgets('saves a new display name', (tester) async {
      await openSettings(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'Atharva',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(container.read(displayNameProvider).value, 'Atharva');
    });

    testWidgets('reports that the device can host', (tester) async {
      await openSettings(tester);

      expect(find.text('Can host groups'), findsOneWidget);
    });

    testWidgets(
        "fails closed and reports that the device can't host when the "
        'peripheral probe fails', (tester) async {
      await openSettings(tester, peripheralError: Exception('probe failed'));

      // Regression test: this screen used to read
      // `peripheralSupportedProvider.value` directly, which is `null` on
      // `AsyncError` — so `canHost == false` was also false, and a device
      // whose capability probe genuinely failed was told it could host.
      // home_screen_test.dart's "disables Create New Group when the
      // peripheral probe fails" test covers Home's side of this same fact.
      expect(find.text("Can't host groups"), findsOneWidget);
      expect(find.text('Can host groups'), findsNothing);
    });

    testWidgets('clears recent groups', (tester) async {
      SharedPreferences.setMockInitialValues({
        'recent_groups': [
          '{"groupId":"1a2b","name":"Team Alpha","memberCount":3,'
              '"lastJoined":"2026-08-26T12:00:00.000"}',
        ],
      });

      await openSettings(tester);
      await tester.tap(find.text('Clear recent groups'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('No groups yet'), findsOneWidget);
    });

    testWidgets('limits the display name to the wire byte budget',
        (tester) async {
      await openSettings(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'a' * (ProtocolLimits.maxDisplayNameBytes + 10),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).first);

      expect(field.controller!.text.length, ProtocolLimits.maxDisplayNameBytes);
    });

    testWidgets('counts multi-byte characters against the byte budget',
        (tester) async {
      await openSettings(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'ü' * 40, // 80 bytes
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).first);

      // 31 two-byte characters is 62 bytes; a 32nd would exceed 63.
      expect(field.controller!.text.length, 31);
    });
  });
}
