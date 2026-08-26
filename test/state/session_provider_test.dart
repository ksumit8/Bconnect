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

  test('reset clears a failure back to idle', () async {
    final notifier = container.read(sessionProvider.notifier);
    await notifier.createGroup(
      const GroupConfig(name: 'Team Alpha'),
      displayName: 'You',
    );
    await notifier.leave();

    notifier.reset();

    expect(container.read(sessionProvider), isA<SessionIdle>());
  });
}
