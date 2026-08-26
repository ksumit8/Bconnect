import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CallControls extends StatelessWidget {
  const CallControls({
    required this.muted,
    required this.talking,
    required this.onSpeaker,
    required this.onToggleMute,
    required this.onTalkStart,
    required this.onTalkStop,
    required this.onEndCall,
    super.key,
  });

  final bool muted;
  final bool talking;
  final VoidCallback onSpeaker;
  final VoidCallback onToggleMute;
  final VoidCallback onTalkStart;
  final VoidCallback onTalkStop;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundButton(
              icon: Icons.volume_up,
              label: 'Speaker',
              background: AppColors.active,
              onTap: onSpeaker,
            ),
            // Hold to transmit (spec section 3.3); the label follows the
            // mockups.
            GestureDetector(
              onTapDown: (_) => onTalkStart(),
              onTapUp: (_) => onTalkStop(),
              onTapCancel: onTalkStop,
              child: Column(
                children: [
                  Container(
                    height: 76,
                    width: 76,
                    decoration: BoxDecoration(
                      color: talking ? AppColors.active : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to Speak',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            _RoundButton(
              icon: muted ? Icons.mic_off : Icons.mic_none,
              label: 'Mute',
              background:
                  muted ? AppColors.danger : AppColors.surfaceRaised,
              onTap: onToggleMute,
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onEndCall,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('End Call'),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
