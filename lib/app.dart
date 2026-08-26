import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class BconnectApp extends StatelessWidget {
  const BconnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Group Talk',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}
