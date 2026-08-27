import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/core/router/app_router.dart';
import 'package:bconnect/main.dart' as app;
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/ble/ble_transport.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/ui/common/action_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app builds with a dark theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final transport = FakeTransport(FakeHub(), deviceId: 'me');
    addTearDown(transport.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [transportProvider.overrideWithValue(transport)],
        child: BconnectApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme!.brightness, Brightness.dark);
  });

  // Regression test for the app having shipped with no transport wired at
  // all: `lib/main.dart`'s `main()` used to call
  // `runApp(const ProviderScope(child: BconnectApp()))` with no overrides,
  // so `transportProvider` threw `UnimplementedError` at runtime and Create
  // was permanently disabled. Every other test in this suite overrides
  // `transportProvider` itself and so could not have caught that.
  //
  // This pumps `buildProductionApp()` — the exact widget tree `main()` calls
  // `runApp()` with, overrides and all — rather than reconstructing an
  // equivalent `ProviderScope` by hand, so it fails again if that override
  // is ever removed from `lib/main.dart`, forgotten, or broken by Plan B's
  // swap to the real BLE transport. (Calling `main()` itself here, instead
  // of pumping its widget, trips an unrelated `AnimationController`
  // assertion: `runApp`'s synchronous warm-up frame doesn't interact well
  // with the test binding's clock, whereas `tester.pumpWidget` does.)
  //
  // Since Plan B1 Task 4 the production transport is the real `BleTransport`,
  // which needs a radio. So this can no longer assert Create ends up *enabled*
  // — off-device `isPeripheralSupported()` fails and the home screen correctly
  // says the device can't host. What it asserts instead is stronger against
  // the original bug: that the override exists at all, and that it is the real
  // transport rather than a fake that leaked into the shipping build.
  testWidgets('main() wires the real BLE transport into the running app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(app.buildProductionApp());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BconnectApp)),
    );
    final transport = container.read(transportProvider);

    expect(transport, isA<BleTransport>());
    expect(transport, isNot(isA<FakeTransport>()));

    // And the tree it builds actually renders.
    expect(find.text('Group Talk'), findsOneWidget);
    expect(find.text('Create New Group'), findsOneWidget);
  });

  // The enabled-Create path still needs covering, so cover it where it can be:
  // over a transport that reports hosting is supported.
  testWidgets('Create is enabled when the transport can host', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final transport = FakeTransport(FakeHub(), deviceId: 'me');
    addTearDown(transport.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [transportProvider.overrideWithValue(transport)],
        child: BconnectApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("This device can't host a group"), findsNothing);

    final createCard = tester.widget<ActionCard>(
      find.widgetWithText(ActionCard, 'Create New Group'),
    );
    expect(createCard.onTap, isNotNull);
  });
}
