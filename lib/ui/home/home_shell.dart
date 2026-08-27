import 'package:flutter/material.dart';

import '../settings/settings_screen.dart';
import 'home_screen.dart';

/// Bottom navigation over the three top-level destinations in drawing 1.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Whether the Settings tab has ever been opened.
  ///
  /// `IndexedStack` builds every child eagerly, even the offstage ones. That
  /// matters here because `SettingsScreen` watches `displayNameProvider`,
  /// which reads `SharedPreferences` — so an eagerly-built Settings tab starts
  /// a platform-channel load the moment the app launches, before the user has
  /// gone anywhere near it. Besides being wasted startup work, it leaves a
  /// pending future alive for the app's whole lifetime.
  ///
  /// Deferring the real screen until its tab is first selected keeps the
  /// `IndexedStack` (so tab state is still preserved once visited) without
  /// paying for a tab nobody has opened.
  bool _settingsVisited = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          const HomeScreen(),
          if (_settingsVisited)
            const SettingsScreen(embedded: true)
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          if (i == 2) _settingsVisited = true;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
