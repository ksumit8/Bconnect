import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/audio.dart';
import '../../state/audio_route_provider.dart';

class AudioOutputScreen extends ConsumerWidget {
  const AudioOutputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(audioRouteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audio Output')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _RouteOption(
              icon: Icons.volume_up,
              label: 'Speaker',
              selected: route == AudioRoute.speaker,
              onTap: () => ref
                  .read(audioRouteProvider.notifier)
                  .setRoute(AudioRoute.speaker),
            ),
            const SizedBox(height: 12),
            _RouteOption(
              icon: Icons.hearing,
              label: 'Earpiece',
              selected: route == AudioRoute.earpiece,
              onTap: () => ref
                  .read(audioRouteProvider.notifier)
                  .setRoute(AudioRoute.earpiece),
            ),
            const SizedBox(height: 28),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Speaker for group communication',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Use Earpiece for private listening',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
