import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    transport = FakeTransport(FakeHub(), deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  Future<void> pumpApp(
    WidgetTester tester, {
    bool peripheral = true,
    Object? peripheralError,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transportProvider.overrideWithValue(transport),
          peripheralSupportedProvider.overrideWith((ref) async {
            if (peripheralError != null) throw peripheralError;
            return peripheral;
          }),
        ],
        // A fresh router per test: appRouter is a process-wide singleton
        // that remembers its current location across pumpWidget calls in
        // the same test file, so reusing it here would leak navigation
        // from one test into the next.
        child: BconnectApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the app title and both action cards', (tester) async {
    await pumpApp(tester);

    expect(find.text('Group Talk'), findsOneWidget);
    expect(find.text('Bluetooth Communication'), findsOneWidget);
    expect(find.text('Create New Group'), findsOneWidget);
    expect(find.text('Join Existing Group'), findsOneWidget);
  });

  testWidgets('shows the bottom navigation destinations', (tester) async {
    await pumpApp(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping Create New Group navigates away from home',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();

    // The pushed route covers the shell, so the bottom bar is gone.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('tapping Join Existing Group opens the discover route',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Join Existing Group'));
    await tester.pumpAndSettle();

    expect(find.text('Join Group'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('says the list is empty when there are no recent groups',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('No groups yet'), findsOneWidget);
  });

  testWidgets('lists a stored recent group', (tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_groups': [
        '{"groupId":"1a2b","name":"Team Alpha","memberCount":3,'
            '"lastJoined":"2026-08-26T12:00:00.000"}',
      ],
    });

    await pumpApp(tester);

    expect(find.text('Team Alpha'), findsOneWidget);
    expect(find.text('3 Members'), findsOneWidget);
  });

  testWidgets('disables Create New Group without peripheral support',
      (tester) async {
    await pumpApp(tester, peripheral: false);

    expect(
      find.text("This device can't host a group"),
      findsOneWidget,
    );

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();

    // Still on home: the tap did nothing, so the shell is still visible.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
      'disables Create New Group when the peripheral probe fails',
      (tester) async {
    await pumpApp(tester, peripheralError: Exception('probe failed'));

    expect(
      find.text("This device can't host a group"),
      findsOneWidget,
    );

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();

    // Still on home: the tap did nothing, so the shell is still visible.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
