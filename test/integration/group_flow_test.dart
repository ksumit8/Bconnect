import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/discovered_group.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/domain/session/client_session.dart';
import 'package:bconnect/domain/session/host_session.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

/// One simulated device.
class _Device {
  _Device(this.transport, this.session);

  final FakeTransport transport;
  final ClientSession session;

  Future<void> dispose() async {
    await session.dispose();
    await transport.dispose();
  }
}

void main() {
  late FakeHub hub;
  late FakeTransport hostTransport;
  late HostSession host;
  final devices = <_Device>[];

  setUp(() {
    hub = FakeHub();
    hostTransport = FakeTransport(hub, deviceId: 'host');
  });

  tearDown(() async {
    for (final d in devices) {
      await d.dispose();
    }
    devices.clear();
    await host.dispose();
    await hostTransport.dispose();
  });

  Future<void> startHost({String? password}) async {
    host = HostSession(
      transport: hostTransport,
      config: GroupConfig(name: 'Team Alpha', password: password),
      hostDisplayName: 'You',
      random: Random(11),
    );
    await host.start();
  }

  Future<DiscoveredGroup> discoverWith(FakeTransport t) async {
    final found = t.events.whereType<ScanResultEvent>().first;
    await t.startScan();
    return (await found).group;
  }

  Future<_Device> joinDevice(String name, {String? password}) async {
    final transport = FakeTransport(hub, deviceId: 'dev-$name');
    final session = ClientSession(transport: transport, displayName: name);
    final device = _Device(transport, session);
    devices.add(device);

    final group = await discoverWith(transport);
    final connected =
        session.states.firstWhere((s) => s is SessionConnected);
    await session.join(group, password: password);
    await connected;

    return device;
  }

  test('three clients join an open group and everyone sees four members',
      () async {
    await startHost();

    await joinDevice('Device 1');
    await joinDevice('Device 2');
    final third = await joinDevice('Device 3');

    await Future<void>.delayed(Duration.zero);

    expect((host.state as SessionConnected).roster.length, 4);
    expect((third.session.state as SessionConnected).roster.length, 4);

    for (final d in devices) {
      final state = d.session.state as SessionConnected;
      expect(state.roster.where((m) => m.isSelf).length, 1);
    }
  });

  test('three clients join a password group with the right password',
      () async {
    await startHost(password: 'hunter2');

    await joinDevice('Device 1', password: 'hunter2');
    await joinDevice('Device 2', password: 'hunter2');
    await joinDevice('Device 3', password: 'hunter2');

    await Future<void>.delayed(Duration.zero);

    expect((host.state as SessionConnected).roster.length, 4);
  });

  test('the advertised member count tracks the roster', () async {
    await startHost();
    await joinDevice('Device 1');
    await joinDevice('Device 2');

    final scanner = FakeTransport(hub, deviceId: 'scanner');
    addTearDown(scanner.dispose);

    expect((await discoverWith(scanner)).memberCount, 3);
  });

  test('concurrent talkers are capped, and the floor frees up again',
      () async {
    await startHost();

    final talkers = <_Device>[];
    for (var i = 0; i < ProtocolLimits.maxConcurrentTalkers; i++) {
      talkers.add(await joinDevice('Talker $i'));
    }
    final extra = await joinDevice('One Too Many');

    for (final d in talkers) {
      expect(await d.session.requestTalk(), isTrue);
    }
    await Future<void>.delayed(Duration.zero);

    expect(await extra.session.requestTalk(), isFalse);

    await talkers.first.session.stopTalk();
    await Future<void>.delayed(Duration.zero);

    expect(await extra.session.requestTalk(), isTrue);
  });

  test('a member leaving is removed from every other roster', () async {
    await startHost();

    final first = await joinDevice('Device 1');
    final second = await joinDevice('Device 2');

    final shrunk = second.session.states.firstWhere(
      (s) => s is SessionConnected && s.roster.length == 2,
    );

    await first.session.leave();

    expect((await shrunk as SessionConnected).roster.length, 2);
    expect((host.state as SessionConnected).roster.length, 2);
  });

  test('ending the group fails every client with hostLeft', () async {
    await startHost();

    final a = await joinDevice('Device 1');
    final b = await joinDevice('Device 2');

    final aFailed = a.session.states.firstWhere((s) => s is SessionFailed);
    final bFailed = b.session.states.firstWhere((s) => s is SessionFailed);

    await host.stop();

    expect((await aFailed as SessionFailed).error, SessionError.hostLeft);
    expect((await bFailed as SessionFailed).error, SessionError.hostLeft);
    expect(host.state, isA<SessionIdle>());
  });

  test('the group fills up and refuses an extra member', () async {
    await startHost();

    for (var i = 0; i < ProtocolLimits.maxMembers - 1; i++) {
      await joinDevice('Device $i');
    }
    await Future<void>.delayed(Duration.zero);

    expect((host.state as SessionConnected).roster.length,
        ProtocolLimits.maxMembers);

    final transport = FakeTransport(hub, deviceId: 'dev-extra');
    final session =
        ClientSession(transport: transport, displayName: 'Extra');
    devices.add(_Device(transport, session));

    final group = await discoverWith(transport);
    expect(group.isFull, isTrue);

    final failed = session.states.firstWhere((s) => s is SessionFailed);
    await session.join(group);

    expect((await failed as SessionFailed).error, SessionError.groupFull);
  });
}
