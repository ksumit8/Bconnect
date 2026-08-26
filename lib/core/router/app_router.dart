import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/home/home_shell.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeShell(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => const _Pending('Create New Group'),
        ),
        GoRoute(
          path: 'discover',
          builder: (context, state) => const _Pending('Join Group'),
        ),
        GoRoute(
          path: 'join',
          builder: (context, state) => const _Pending('Join Group'),
        ),
        GoRoute(
          path: 'group',
          builder: (context, state) => const _Pending('Group'),
          routes: [
            GoRoute(
              path: 'audio',
              builder: (context, state) => const _Pending('Audio Output'),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Replaced task by task as each screen lands.
class _Pending extends StatelessWidget {
  const _Pending(this.title);

  final String title;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)));
}
