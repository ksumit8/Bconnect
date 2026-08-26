import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class BconnectApp extends StatelessWidget {
  const BconnectApp({this.router, super.key});

  /// Overridable for tests so each one gets its own navigation stack
  /// instead of sharing the process-wide [appRouter] singleton.
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Group Talk',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      theme: AppTheme.dark,
      routerConfig: router ?? appRouter,
    );
  }
}
