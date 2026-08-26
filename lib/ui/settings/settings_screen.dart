import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({this.embedded = false, super.key});

  /// True when hosted inside the bottom navigation rather than pushed.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Settings')),
      body: const SafeArea(child: SizedBox.shrink()),
    );
  }
}
