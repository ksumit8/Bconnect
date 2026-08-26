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
import 'package:bconnect/transport/group_transport.dart';

/// A transport whose [startAdvertising] always fails, so a test can exercise
/// what the create screen does when the radio can't start advertising (e.g.
/// Bluetooth toggled off mid-create) without a real BLE radio.
class _FailingAdvertiseTransport extends FakeTransport {
  _FailingAdvertiseTransport(super.hub) : super(deviceId: 'failing-host');

  @override
  Future<void> startAdvertising({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
    int rssi = -55,
  }) {
    throw const TransportException('advertise failed');
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

  Future<void> openCreateScreen(
    WidgetTester tester, {
    GroupTransport? overrideTransport,
  }) async {
    container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(overrideTransport ?? transport),
      ],
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

  /// Scans on a second transport sharing [hub] with the host, and returns
  /// whether the discovered group advertises as locked. This is the only
  /// way to tell a real password group from one that silently dropped its
  /// lock: `HostSession.start()` reaches `SessionConnected` regardless of
  /// whether a password was set.
  Future<bool> scanIsLocked(WidgetTester tester) async {
    final scanner = FakeTransport(hub, deviceId: 'scanner');
    addTearDown(scanner.dispose);

    final found = scanner.events.whereType<ScanResultEvent>().first;
    await scanner.startScan();
    // FakeHub.deliverCurrentAdverts defers delivery to the next event-loop
    // turn via a real Timer. Widget tests run on a fake clock that only
    // fires pending real Timers once it's elapsed by a positive duration —
    // pump(Duration.zero) (the default) does not do it.
    await tester.pump(const Duration(milliseconds: 10));
    final event = await found;

    return event.group.isLocked;
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
    expect(await scanIsLocked(tester), isFalse);
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
    expect(await scanIsLocked(tester), isTrue);
  });

  testWidgets(
      'shows an error and re-enables the button when advertising fails',
      (tester) async {
    final failingTransport = _FailingAdvertiseTransport(hub);
    addTearDown(failingTransport.dispose);

    await openCreateScreen(tester, overrideTransport: failingTransport);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );

    // HostSession.start()'s failure path cancels a stream subscription on
    // the way out. A StreamController.broadcast() subscription's cancel()
    // future never resolves under plain pump()/pumpAndSettle() inside
    // testWidgets — a flutter_test fake-async-zone quirk (confirmed
    // separately: the identical cancel() resolves in 0ms under a plain
    // `test()`, so this is a test-harness property, not a production
    // bug). Run the tap and its async fallout for real via runAsync, then
    // let the tree settle normally.
    Future<void> tapAndLetRealAsyncSettle() async {
      await tester.ensureVisible(
        find.text('Create Group', skipOffstage: false),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Create Group'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
    }

    await tapAndLetRealAsyncSettle();

    expect(find.text('Could not create the group'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());

    // The button must have come back to life rather than staying stuck in
    // the busy state — tap it again and confirm it still responds.
    await tapAndLetRealAsyncSettle();

    expect(find.text('Could not create the group'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });
}
