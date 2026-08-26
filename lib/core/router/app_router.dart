import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/discovered_group.dart';
import '../../ui/create/create_group_screen.dart';
import '../../ui/discover/discover_screen.dart';
import '../../ui/group/group_screen.dart';
import '../../ui/home/home_shell.dart';
import '../../ui/join/join_password_screen.dart';

/// Builds a fresh router with a clean navigation stack.
///
/// `appRouter` below is the single production instance, shared by the whole
/// app for its lifetime. Widget tests should call this instead of reusing
/// `appRouter`: `GoRouter` is stateful (it remembers the current location
/// across `pumpWidget` calls), so sharing one instance across tests in the
/// same file lets an earlier test's navigation leak into the next test's
/// initial route.
GoRouter buildAppRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeShell(),
          routes: [
            GoRoute(
              path: 'create',
              builder: (context, state) => const CreateGroupScreen(),
            ),
            GoRoute(
              path: 'discover',
              builder: (context, state) => const DiscoverScreen(),
            ),
            GoRoute(
              path: 'join',
              builder: (context, state) => JoinPasswordScreen(
                group: state.extra! as DiscoveredGroup,
              ),
            ),
            GoRoute(
              path: 'group',
              builder: (context, state) => const GroupScreen(),
              routes: [
                GoRoute(
                  path: 'audio',
                  builder: (context, state) =>
                      const _Pending('Audio Output'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

final appRouter = buildAppRouter();

/// Replaced task by task as each screen lands.
class _Pending extends StatelessWidget {
  const _Pending(this.title);

  final String title;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)));
}
