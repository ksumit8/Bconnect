import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/app.dart';

void main() {
  testWidgets('app builds with a dark theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BconnectApp()));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(materialApp.darkTheme, isNotNull);
    expect(materialApp.darkTheme!.brightness, Brightness.dark);
  });
}
