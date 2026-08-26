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
}
