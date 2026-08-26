import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    transport = FakeTransport(FakeHub(), deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  Future<void> openCreateScreen(WidgetTester tester) async {
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
  }

  // The form is taller than the default test surface, so the Create Group
  // button sits below the fold. `find.text` skips offstage matches by
  // default, so scroll it into view before asserting on or tapping it.
  Future<void> tapCreateButton(WidgetTester tester) async {
    await tester.ensureVisible(
      find.text('Create Group', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the name field and both security options',
      (tester) async {
    await openCreateScreen(tester);

    expect(find.text('Group Name'), findsOneWidget);
    expect(find.text('Enter group name'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Open Group'), findsOneWidget);
    expect(find.text('Password Protected'), findsOneWidget);

    await tester.ensureVisible(
      find.text('Create Group', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create Group'), findsWidgets);
  });

  testWidgets('defaults to an open group with the password field disabled',
      (tester) async {
    await openCreateScreen(tester);

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Enter password'),
    );

    expect(field.enabled, isFalse);
  });

  testWidgets('choosing password protection enables the password field',
      (tester) async {
    await openCreateScreen(tester);

    await tester.tap(find.text('Password Protected'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Enter password'),
    );

    expect(field.enabled, isTrue);
  });

  testWidgets('refuses an empty group name', (tester) async {
    await openCreateScreen(tester);

    await tapCreateButton(tester);

    expect(find.text('Enter a group name'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  testWidgets('refuses password protection with no password', (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tester.tap(find.text('Password Protected'));
    await tester.pumpAndSettle();

    await tapCreateButton(tester);

    expect(find.text('Enter a password'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  testWidgets('limits the name to the advertised byte budget',
      (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'a' * (ProtocolLimits.maxGroupNameBytes + 10),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Enter group name'),
    );

    expect(
      field.controller!.text.length,
      ProtocolLimits.maxGroupNameBytes,
    );
  });

  testWidgets('counts multi-byte characters against the byte budget',
      (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'ü' * 20, // 40 bytes
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Enter group name'),
    );

    // 14 two-byte characters is 28 bytes; a fifteenth would exceed 29.
    expect(field.controller!.text.length, 14);
  });

  testWidgets('creates an open group and opens the group screen',
      (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tapCreateButton(tester);

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.groupName, 'Team Alpha');
    expect(state.isHost, isTrue);
  });

  testWidgets('creates a password group', (tester) async {
    await openCreateScreen(tester);

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
    await tapCreateButton(tester);

    expect(container.read(sessionProvider), isA<SessionConnected>());
  });
}
