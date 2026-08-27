import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/discovered_group.dart';
import '../../domain/models/session_state.dart';
import '../../state/discovered_groups_provider.dart';
import '../../state/display_name_provider.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/session_provider.dart';
import '../../transport/group_transport.dart';
import 'widgets/group_tile.dart';

/// Maps a failed join to copy a user can act on (spec section 8).
String _errorMessage(SessionError error) => switch (error) {
      SessionError.groupFull => 'That group is full',
      SessionError.wrongPassword => 'Incorrect password',
      SessionError.incompatibleVersion => 'Incompatible app version',
      _ => 'Could not join the group',
    };

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  // Guards against a re-entrant join: without it, a second tap while the
  // first join is still awaiting its handshake starts a second `joinGroup`,
  // whose `_teardown()` disposes the first `ClientSession` mid-flight (see
  // `SessionController.joinGroup`'s `orElse` fix for the `StateError` that
  // used to cause).
  bool _joining = false;

  Future<void> _join(BuildContext context, DiscoveredGroup group) async {
    if (group.isLocked) {
      context.push('/join', extra: group);
      return;
    }

    if (_joining) return;
    _joining = true;

    try {
      final displayName = await ref.read(displayNameProvider.future);
      if (!context.mounted) return;

      // `ClientSession.join` resolves to `SessionFailed` rather than
      // throwing for protocol-level rejections (wrong password, full,
      // incompatible version, connection lost); this try/catch only guards
      // the genuinely-throwing case, e.g. a `TransportException` surfacing
      // some other way.
      try {
        await ref
            .read(sessionProvider.notifier)
            .joinGroup(group, displayName: displayName);
      } on TransportException {
        if (!context.mounted) return;
        ref.read(sessionProvider.notifier).reset();
        _showError(context, 'Could not join the group');
        return;
      }

      // Backing out of this screen while the handshake is in flight unmounts
      // the widget and disposes `discoveredGroupsProvider`; guard before
      // touching `ref` again so that doesn't throw a `StateError`.
      if (!context.mounted) return;

      final state = ref.read(sessionProvider);
      switch (state) {
        case SessionConnected():
          await ref.read(recentGroupsProvider.notifier).record(
                groupId: state.groupId,
                name: state.groupName,
                memberCount: state.roster.length,
              );
          if (context.mounted) context.go('/group');
        case SessionFailed(:final error):
          ref.read(sessionProvider.notifier).reset();
          _showError(context, _errorMessage(error));
        case SessionIdle():
        case SessionDiscovering():
        case SessionJoining():
          break;
      }
    } finally {
      // Only reset the guard if the screen is still around to reuse it;
      // touching `mounted`-gated state on a disposed State is otherwise
      // harmless here since `_joining` is a plain field, but there is no
      // reason to write it once the screen is gone.
      if (mounted) _joining = false;
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(discoveredGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Scanning for nearby groups...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (groups) {
                AsyncData(value: final list) when list.isEmpty => const Center(
                    child: Text(
                      'No groups found nearby',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                AsyncData(value: final list) => ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final g in list)
                        GroupTile(
                          group: g,
                          onTap: g.isFull ? null : () => _join(context, g),
                        ),
                    ],
                  ),
                AsyncError(:final error) => Center(
                    child: Text(
                      'Scan failed: $error',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () => ref.invalidate(discoveredGroupsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
