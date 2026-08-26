import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/group_config.dart';
import '../../domain/models/session_state.dart';
import '../../domain/protocol/protocol_limits.dart';
import '../../state/display_name_provider.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/session_provider.dart';
import '../common/utf8_byte_limit_formatter.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();

  bool _locked = false;
  bool _obscure = true;
  bool _busy = false;
  String? _nameError;
  String? _passwordError;

  /// Set when [_create] fails after validation passes — e.g. the radio
  /// can't start advertising because Bluetooth was toggled off mid-create.
  /// Distinct from [_nameError]/[_passwordError], which are field-level
  /// validation and not the group name's or password's fault here.
  String? _createError;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final password = _password.text;

    setState(() {
      _nameError = name.isEmpty ? 'Enter a group name' : null;
      _passwordError =
          _locked && password.isEmpty ? 'Enter a password' : null;
    });

    if (_nameError != null || _passwordError != null) return;

    setState(() {
      _busy = true;
      _createError = null;
    });

    SessionState? state;
    var failed = false;

    try {
      final displayName = await ref.read(displayNameProvider.future);
      await ref.read(sessionProvider.notifier).createGroup(
            GroupConfig(name: name, password: _locked ? password : null),
            displayName: displayName,
          );

      state = ref.read(sessionProvider);
      if (state is SessionConnected) {
        await ref.read(recentGroupsProvider.notifier).record(
              groupId: state.groupId,
              name: state.groupName,
              memberCount: state.roster.length,
            );
      }
    } catch (_) {
      // Most commonly the radio failing to start advertising (Bluetooth
      // toggled off mid-create). The session stays idle in that case, so
      // there is nothing to tear down — just let the user retry.
      failed = true;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _createError = failed ? 'Could not create the group' : null;
        });
      }
    }

    if (!mounted || failed) return;

    if (state is SessionConnected) context.go('/group');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Group')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.groups, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            const _Label('Group Name'),
            TextField(
              controller: _name,
              inputFormatters: const [
                Utf8ByteLimitFormatter(ProtocolLimits.maxGroupNameBytes),
              ],
              decoration: InputDecoration(
                hintText: 'Enter group name',
                filled: true,
                fillColor: AppColors.surface,
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const _Label('Security'),
            _SecurityOption(
              icon: Icons.public,
              title: 'Open Group',
              subtitle: 'Anyone can join',
              selected: !_locked,
              onTap: () => setState(() => _locked = false),
            ),
            const SizedBox(height: 8),
            _SecurityOption(
              icon: Icons.lock,
              title: 'Password Protected',
              subtitle: 'Only with password',
              selected: _locked,
              onTap: () => setState(() => _locked = true),
            ),
            const SizedBox(height: 24),
            const _Label('Password (optional)'),
            TextField(
              controller: _password,
              enabled: _locked,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Enter password',
                filled: true,
                fillColor: AppColors.surface,
                errorText: _passwordError,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_createError != null) ...[
              const SizedBox(height: 16),
              Text(
                _createError!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
}

class _SecurityOption extends StatelessWidget {
  const _SecurityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.active : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
