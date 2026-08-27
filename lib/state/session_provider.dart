import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/discovered_group.dart';
import '../domain/models/group_config.dart';
import '../domain/models/session_state.dart';
import '../domain/session/client_session.dart';
import '../domain/session/host_session.dart';
import 'transport_provider.dart';

/// Owns whichever role the device is currently playing.
///
/// Not autoDispose: an active call must survive navigating away from the
/// group screen (spec section 6.2).
class SessionController extends Notifier<SessionState> {
  HostSession? _host;
  ClientSession? _client;
  StreamSubscription<SessionState>? _subscription;

  @override
  SessionState build() {
    ref.onDispose(() {
      unawaited(_teardown());
    });
    return const SessionState.idle();
  }

  Future<void> createGroup(
    GroupConfig config, {
    required String displayName,
  }) async {
    await _teardown();

    final host = HostSession(
      transport: ref.read(transportProvider),
      config: config,
      hostDisplayName: displayName,
    );
    _host = host;
    _subscription = host.states.listen((s) => state = s);

    await host.start();
    state = host.state;
  }

  Future<void> joinGroup(
    DiscoveredGroup group, {
    String? password,
    required String displayName,
  }) async {
    await _teardown();

    final client = ClientSession(
      transport: ref.read(transportProvider),
      displayName: displayName,
    );
    _client = client;
    _subscription = client.states.listen((s) => state = s);

    // Completes once the handshake settles either way. `orElse` covers a
    // re-entrant join (a second call to joinGroup/leave tearing this client
    // down while this one is still in flight): `_teardown()` disposes the
    // client, closing `_states`, and `Stream.firstWhere` with no `orElse`
    // completes with an uncaught `StateError` when the stream ends
    // unmatched. Falling back to idle here mirrors `leave()`'s own outcome.
    final settled = client.states.firstWhere(
      (s) => s is SessionConnected || s is SessionFailed,
      orElse: () => const SessionState.idle(),
    );

    await client.join(group, password: password);
    state = await settled;
  }

  Future<void> leave() async {
    await _host?.stop();
    await _client?.leave();
    await _teardown();
    state = const SessionState.idle();
  }

  Future<bool> requestTalk() async =>
      await _host?.requestTalk() ?? await _client?.requestTalk() ?? false;

  Future<void> stopTalk() async {
    await _host?.stopTalk();
    await _client?.stopTalk();
  }

  /// Dismisses a failure without tearing anything else down.
  void reset() => state = const SessionState.idle();

  Future<void> _teardown() async {
    await _subscription?.cancel();
    _subscription = null;

    await _host?.dispose();
    await _client?.dispose();
    _host = null;
    _client = null;
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
