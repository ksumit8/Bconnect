import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/member.dart';

class MemberTile extends StatelessWidget {
  const MemberTile({required this.member, super.key});

  final Member member;

  String get _label {
    if (member.isSelf) return member.isHost ? 'You (Admin)' : 'You';
    return member.displayName;
  }

  String get _presence => switch (member.presence) {
        MemberPresence.online => 'Online',
        MemberPresence.reconnecting => 'Reconnecting',
        MemberPresence.offline => 'Offline',
      };

  Color get _presenceColor => switch (member.presence) {
        MemberPresence.online => AppColors.active,
        MemberPresence.reconnecting => Colors.amber,
        MemberPresence.offline => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceRaised,
          child: Icon(
            member.isTalking ? Icons.graphic_eq : Icons.person,
            color: member.isTalking
                ? AppColors.active
                : AppColors.textSecondary,
          ),
        ),
        title: Text(
          _label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _presence,
          style: TextStyle(color: _presenceColor, fontSize: 12),
        ),
        trailing: Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: _presenceColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
