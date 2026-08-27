import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/protocol/protocol_limits.dart';
import '../../state/display_name_provider.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/transport_provider.dart';
import '../common/utf8_byte_limit_formatter.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({this.embedded = false, super.key});

  /// True when hosted inside the bottom navigation rather than pushed.
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Seed the field once the stored name has loaded.
    //
    // This runs through `ref.listen` rather than inline in `build`, because
    // assigning to `TextEditingController.text` calls `notifyListeners()`
    // synchronously. Doing that during build marks dependents dirty mid-build,
    // and since this screen lives in `HomeShell`'s `IndexedStack` it is built
    // even while offstage — so the resulting rebuild kept scheduling frames
    // and `pumpAndSettle()` never converged anywhere in the app's tests.
    // `ref.listen` fires after the frame, so the assignment is safe.
    ref.listen<AsyncValue<String>>(displayNameProvider, (previous, next) {
      if (!_seeded && next.hasValue) {
        _seeded = true;
        _name.text = next.value!;
      }
    });

    final displayName = ref.watch(displayNameProvider);
    // Fails closed the same way Home's Create card does — see
    // `canHostProvider`'s doc. Previously this read `.value` off
    // `peripheralSupportedProvider` directly, which is `null` on
    // `AsyncError`, so a device whose capability probe failed was told it
    // could host.
    final canHost = ref.watch(canHostProvider);

    // The provider may already have resolved before this screen first built,
    // in which case `ref.listen` above will not fire for that value.
    if (!_seeded && displayName.hasValue) {
      _seeded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _name.text = displayName.value!;
      });
    }

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.embedded)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            const Text(
              'Display Name',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              inputFormatters: const [
                Utf8ByteLimitFormatter(ProtocolLimits.maxDisplayNameBytes),
              ],
              decoration: const InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => ref
                    .read(displayNameProvider.notifier)
                    .setName(_name.text),
                child: const Text('Save'),
              ),
            ),
            const Divider(height: 40),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                canHost ? Icons.bluetooth : Icons.error_outline,
                color: canHost ? AppColors.textSecondary : AppColors.danger,
              ),
              title: Text(
                canHost ? 'Can host groups' : "Can't host groups",
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                canHost
                    ? 'This device can create and advertise groups.'
                    : "This device's Bluetooth can't advertise, so it can "
                        'only join groups.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            const Divider(height: 40),
            TextButton.icon(
              onPressed: () =>
                  ref.read(recentGroupsProvider.notifier).clear(),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear recent groups'),
            ),
          ],
        ),
      ),
    );
  }
}
