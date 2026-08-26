import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/discovered_group.dart';
import 'signal_bars.dart';

class GroupTile extends StatelessWidget {
  const GroupTile({required this.group, required this.onTap, super.key});

  final DiscoveredGroup group;

  /// Null when the group cannot be joined, which is how a full group is
  /// shown as unavailable before it is tapped (spec section 8).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final members =
        group.memberCount == 1 ? '1 Member' : '${group.memberCount} Members';

    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: onTap,
          title: Text(
            group.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            group.isFull ? '$members · Full' : members,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                group.isLocked ? Icons.lock : Icons.lock_open,
                size: 18,
                color: group.isLocked
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              SignalBars(rssi: group.rssi),
            ],
          ),
        ),
      ),
    );
  }
}
