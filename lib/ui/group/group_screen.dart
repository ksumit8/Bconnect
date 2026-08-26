import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/session_state.dart';
import '../../state/mic_provider.dart';
import '../../state/session_provider.dart';
import 'widgets/call_controls.dart';
import 'widgets/member_tile.dart';

/// Serves drawings 3, 6 and 8 — one screen, three states.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A group can end underneath us, so failures navigate home with an
    // explanation rather than leaving a dead screen (spec section 8).
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (next is! SessionFailed) return;

      final message = switch (next.error) {
        SessionError.hostLeft => 'Group ended by host',
        SessionError.connectionLost => 'Connection lost',
        SessionError.groupFull => 'That group is full',
        _ => 'Left the group',
      };

      ref.read(sessionProvider.notifier).reset();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      context.go('/');
    });

    final session = ref.watch(sessionProvider);
    final mic = ref.watch(micProvider);

    if (session is! SessionConnected) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final count = session.roster.length;
    // `firstOrNull` lives in package:collection, which is not a direct
    // dependency, so use `any` instead.
    final iAmTalking = session.roster
        .any((m) => m.id == session.myMemberId && m.isTalking);

    return Scaffold(
      appBar: AppBar(
        title: Text(session.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/group/audio'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.active,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.groups, color: Colors.white, size: 26),
                  Text(
                    count == 1 ? '1 Member' : '$count Members',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.active),
                SizedBox(width: 6),
                Text(
                  'Group is Active',
                  style: TextStyle(color: AppColors.active, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Members',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ask others to open Join Group to find this group',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Invite'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final m in session.roster) MemberTile(member: m),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: CallControls(
                muted: mic.muted,
                talking: iAmTalking,
                onSpeaker: () => context.push('/group/audio'),
                onToggleMute: () =>
                    ref.read(micProvider.notifier).toggleMute(),
                onTalkStart: () async {
                  // A muted mic never transmits.
                  if (ref.read(micProvider).muted) return;

                  final granted =
                      await ref.read(sessionProvider.notifier).requestTalk();
                  if (!context.mounted) return;
                  if (!granted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Too many people talking')),
                    );
                    return;
                  }
                  ref.read(micProvider.notifier).setTransmitting(true);
                },
                onTalkStop: () async {
                  await ref.read(sessionProvider.notifier).stopTalk();
                  if (!context.mounted) return;
                  ref.read(micProvider.notifier).setTransmitting(false);
                },
                onEndCall: () async {
                  await ref.read(sessionProvider.notifier).leave();
                  if (context.mounted) context.go('/');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
