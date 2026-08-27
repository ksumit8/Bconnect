import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/transport_provider.dart';
import '../common/action_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A device that cannot advertise can still join, so only hosting is
    // disabled (spec section 8). See `canHostProvider`'s doc for how the
    // loading/error cases are handled.
    final canHost = ref.watch(canHostProvider);
    final recents = ref.watch(recentGroupsProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.bluetooth, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Talk',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Bluetooth Communication',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          ActionCard(
            title: 'Create New Group',
            subtitle: 'Create a group and invite others',
            icon: Icons.add,
            highlighted: true,
            onTap: canHost ? () => context.push('/create') : null,
          ),
          if (!canHost)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "This device can't host a group",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          ActionCard(
            title: 'Join Existing Group',
            subtitle: 'Discover and join available groups',
            icon: Icons.groups,
            onTap: () => context.push('/discover'),
          ),
          const SizedBox(height: 32),
          Text(
            'Your Groups',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          switch (recents) {
            AsyncData(value: final groups) when groups.isEmpty =>
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No groups yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            AsyncData(value: final groups) => Column(
                children: [
                  for (final g in groups)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surfaceRaised,
                          child: Icon(Icons.person),
                        ),
                        title: Text(g.name),
                        subtitle: Text('${g.memberCount} Members'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/discover'),
                      ),
                    ),
                ],
              ),
            AsyncError() => const Text(
                'Could not load your groups',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }
}
