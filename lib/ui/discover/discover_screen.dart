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
import 'widgets/group_tile.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  Future<void> _join(
    BuildContext context,
    WidgetRef ref,
    DiscoveredGroup group,
  ) async {
    if (group.isLocked) {
      context.push('/join', extra: group);
      return;
    }

    final displayName = await ref.read(displayNameProvider.future);
    await ref
        .read(sessionProvider.notifier)
        .joinGroup(group, displayName: displayName);

    final state = ref.read(sessionProvider);
    if (state is SessionConnected) {
      await ref.read(recentGroupsProvider.notifier).record(
            groupId: state.groupId,
            name: state.groupName,
            memberCount: state.roster.length,
          );
      if (context.mounted) context.go('/group');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          onTap:
                              g.isFull ? null : () => _join(context, ref, g),
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
