import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/discovered_group.dart';
import '../../domain/models/session_state.dart';
import '../../state/display_name_provider.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/session_provider.dart';
import '../../transport/group_transport.dart';

class JoinPasswordScreen extends ConsumerStatefulWidget {
  const JoinPasswordScreen({required this.group, super.key});

  final DiscoveredGroup group;

  @override
  ConsumerState<JoinPasswordScreen> createState() =>
      _JoinPasswordScreenState();
}

class _JoinPasswordScreenState extends ConsumerState<JoinPasswordScreen> {
  final _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    // Guards against a re-entrant join: the button already disables itself
    // via `_busy`, but `onSubmitted` (Enter/Done on the keyboard) is not
    // gated by it and can fire `_join` again while the first call is still
    // awaiting its handshake. A second call's `_teardown()` would then
    // dispose the first `ClientSession` mid-flight.
    if (_busy) return;

    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter a password');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final displayName = await ref.read(displayNameProvider.future);
    if (!mounted) return;

    // `ClientSession.join` resolves to `SessionFailed` rather than throwing
    // for protocol-level rejections (wrong password, full, incompatible
    // version, connection lost); this try/catch only guards the genuinely-
    // throwing case, e.g. a `TransportException` surfacing some other way.
    try {
      await ref.read(sessionProvider.notifier).joinGroup(
            widget.group,
            password: _password.text,
            displayName: displayName,
          );
    } on TransportException {
      if (!mounted) return;
      ref.read(sessionProvider.notifier).reset();
      setState(() {
        _busy = false;
        _error = 'Could not join the group';
      });
      return;
    }

    // Backing out of this screen while the handshake is in flight unmounts
    // the widget; guard before touching `ref`/`context` again so that
    // doesn't throw a `StateError`.
    if (!mounted) return;

    final state = ref.read(sessionProvider);
    switch (state) {
      case SessionConnected():
        await ref.read(recentGroupsProvider.notifier).record(
              groupId: state.groupId,
              name: state.groupName,
              memberCount: state.roster.length,
            );
        if (mounted) context.go('/group');
      case SessionFailed(:final error):
        // Stay put so the password can be corrected (spec section 8), and
        // don't leave the session parked in a failed state — Task 18's
        // group screen listens for SessionFailed and would react to a
        // stale one otherwise.
        ref.read(sessionProvider.notifier).reset();
        setState(() {
          _busy = false;
          _error = switch (error) {
            SessionError.wrongPassword => 'Incorrect password',
            SessionError.groupFull => 'That group is full',
            SessionError.incompatibleVersion => 'Incompatible app version',
            _ => 'Could not join the group',
          };
        });
      case _:
        setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.lock, size: 38, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                widget.group.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'This group is password protected',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              'Enter Password',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _join(),
              decoration: InputDecoration(
                hintText: 'Enter Password',
                filled: true,
                fillColor: AppColors.surface,
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _join,
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
                  : const Text('Join Group'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
