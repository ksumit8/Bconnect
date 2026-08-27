import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

/// A transport whose [connect] doesn't resolve until [releaseConnect] is
/// called, so a test can pump execution to the exact point where a join is
/// suspended mid-handshake (after `SessionController` has already assigned
/// `_client`, but before the handshake settles) and only then act.
///
/// Mirrors `_GatedConnectTransport` in `test/ui/discover_screen_test.dart`.
class _GatedConnectTransport extends FakeTransport {
  _GatedConnectTransport(super.hub, {required String deviceId})
      : super(deviceId: deviceId);

  final Completer<void> _gate = Completer<void>();

  void releaseConnect() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<String> connect(String deviceId) async {
    await _gate.future;
    return super.connect(deviceId);
  }
}

void main() {
  late FakeHub hub;
  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    hub = FakeHub();
    transport = FakeTransport(hub, deviceId: 'me');
    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
  });

  tearDown(() async {
    container.dispose();
    await transport.dispose();
  });

  test('starts idle', () {
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  test('transportProvider throws unless overridden', () {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);

    // Riverpod 3.x wraps errors thrown during provider build in a
    // ProviderException (breaking change in 3.0.0-dev.16); the underlying
    // cause is still the UnimplementedError thrown by transportProvider.
    expect(
      () => bare.read(transportProvider),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.exception,
          'exception',
          isA<UnimplementedError>(),
        ),
      ),
    );
  });

  test('createGroup reaches connected as host', () async {
    await container.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha'),
          displayName: 'You',
        );

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.isHost, isTrue);
    expect(state.groupName, 'Team Alpha');
    expect(state.roster.single.isSelf, isTrue);
  });

  test('joinGroup reaches connected as a client', () async {
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);

    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha'),
          displayName: 'Host',
        );

    final found = transport.events.whereType<ScanResultEvent>().first;
    await transport.startScan();
    final group = (await found).group;

    await container
        .read(sessionProvider.notifier)
        .joinGroup(group, displayName: 'Device 1');

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.isHost, isFalse);
    expect(state.roster.length, 2);
  });

  test('joinGroup with the wrong password fails', () async {
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);

    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha', password: 'hunter2'),
          displayName: 'Host',
        );

    final found = transport.events.whereType<ScanResultEvent>().first;
    await transport.startScan();

    await container.read(sessionProvider.notifier).joinGroup(
          (await found).group,
          password: 'nope',
          displayName: 'Device 1',
        );

    expect(
      (container.read(sessionProvider) as SessionFailed).error,
      SessionError.wrongPassword,
    );
  });

  test('leave returns to idle', () async {
    final notifier = container.read(sessionProvider.notifier);
    await notifier.createGroup(
      const GroupConfig(name: 'Team Alpha'),
      displayName: 'You',
    );

    await notifier.leave();

    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  test('requestTalk grants the floor to the host', () async {
    final notifier = container.read(sessionProvider.notifier);
    await notifier.createGroup(
      const GroupConfig(name: 'Team Alpha'),
      displayName: 'You',
    );

    expect(await notifier.requestTalk(), isTrue);
    expect(transport.isTalking, isTrue);

    await notifier.stopTalk();
    expect(transport.isTalking, isFalse);
  });

  // Covers the SessionController level rather than a widget test: a plain
  // "fire both joins without awaiting the first" call pair races two
  // symmetric `_teardown()` calls against each other and, in practice, both
  // resolve before either `joinGroup` has assigned `_client` — so it never
  // lands on the actual bug (confirmed: this passed even with `orElse`
  // removed from `session_provider.dart` when written that way). A
  // `_GatedConnectTransport` is used instead to reliably suspend the first
  // join exactly after `_client` is assigned but before the handshake
  // settles, which is the precise window a re-entrant tap (or a `leave()`)
  // races against.
  test('a re-entrant join does not throw when the first is torn down '
      'mid-flight', () async {
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);

    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha'),
          displayName: 'Host',
        );

    final gated = _GatedConnectTransport(hub, deviceId: 'gated-me');
    addTearDown(gated.dispose);

    final gatedContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(gated)],
    );
    addTearDown(gatedContainer.dispose);

    final found = gated.events.whereType<ScanResultEvent>().first;
    await gated.startScan();
    final group = (await found).group;

    final notifier = gatedContainer.read(sessionProvider.notifier);

    // Starts the first join and lets it run up to (and suspend inside)
    // `connect()` — by which point `SessionController._client` already
    // points at this join's `ClientSession`. Everything up to that point
    // (`_teardown()`'s no-op awaits, then `connect()`'s own await on the
    // still-uncompleted gate) is pure microtasks with nothing scheduled on
    // a real Timer, so a single zero-duration real delay is enough to drain
    // them all before the first join can possibly reach the gate.
    final firstJoin = notifier.joinGroup(group, displayName: 'Device 1');
    await Future<void>.delayed(Duration.zero);

    // The second join's `_teardown()` now disposes the first `ClientSession`
    // mid-handshake, closing its `states` stream before the first call's
    // `firstWhere` can match `SessionConnected`/`SessionFailed` — that must
    // resolve via the `orElse` fallback rather than throw an uncaught
    // `StateError`.
    final secondJoin = notifier.joinGroup(group, displayName: 'Device 1');

    gated.releaseConnect();

    await expectLater(firstJoin, completes);
    await secondJoin;

    expect(gatedContainer.read(sessionProvider), isA<SessionConnected>());
  });

  test('reset clears a failure back to idle', () async {
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);

    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha', password: 'hunter2'),
          displayName: 'Host',
        );

    final found = transport.events.whereType<ScanResultEvent>().first;
    await transport.startScan();

    final notifier = container.read(sessionProvider.notifier);
    await notifier.joinGroup(
      (await found).group,
      password: 'nope',
      displayName: 'Device 1',
    );

    // Actually reach SessionFailed first, or this test would pass just as
    // happily with `reset()`'s body replaced by `{}`.
    expect(container.read(sessionProvider), isA<SessionFailed>());

    notifier.reset();

    expect(container.read(sessionProvider), isA<SessionIdle>());
  });
}
