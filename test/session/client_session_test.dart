import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/discovered_group.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/protocol/control_frame.dart';
import 'package:bconnect/domain/protocol/frame_codec.dart';
import 'package:bconnect/domain/session/client_session.dart';
import 'package:bconnect/domain/session/host_session.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
  late FakeHub hub;
  late FakeTransport hostTransport;
  late FakeTransport clientTransport;
  late HostSession host;
  late ClientSession client;

  setUp(() {
    hub = FakeHub();
    hostTransport = FakeTransport(hub, deviceId: 'host');
    clientTransport = FakeTransport(hub, deviceId: 'client');
    client = ClientSession(
      transport: clientTransport,
      displayName: 'Device 1',
    );
  });

  tearDown(() async {
    await client.dispose();
    await host.dispose();
    await clientTransport.dispose();
    await hostTransport.dispose();
  });

  Future<void> startHost({String? password}) async {
    host = HostSession(
      transport: hostTransport,
      config: GroupConfig(name: 'Team Alpha', password: password),
      hostDisplayName: 'You',
      random: Random(7),
    );
    await host.start();
  }

  /// Discovers the advertised group the way the Discover screen does.
  Future<DiscoveredGroup> discover() async {
    final found = clientTransport.events.whereType<ScanResultEvent>().first;
    await clientTransport.startScan();
    return (await found).group;
  }

  Future<SessionState> connectedState() =>
      client.states.firstWhere((s) => s is SessionConnected);

  Future<SessionState> failedState() =>
      client.states.firstWhere((s) => s is SessionFailed);

  group('join', () {
    test('reaches connected in an open group', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);

      final state = await connected as SessionConnected;

      expect(state.groupName, 'Team Alpha');
      expect(state.isHost, isFalse);
      expect(state.myMemberId, 'm2');
      expect(state.roster.length, 2);
    });

    test('marks its own entry in the roster', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);

      final state = await connected as SessionConnected;
      final me = state.roster.firstWhere((m) => m.id == state.myMemberId);

      expect(me.isSelf, isTrue);
      expect(state.roster.where((m) => m.isSelf).length, 1);
    });

    test('passes through the joining steps in order', () async {
      await startHost();
      final group = await discover();

      final steps = <JoinStep>[];
      client.states.listen((s) {
        if (s is SessionJoining) steps.add(s.step);
      });

      final connected = connectedState();
      await client.join(group);
      await connected;

      expect(steps, containsAllInOrder(
        [JoinStep.connecting, JoinStep.authenticating, JoinStep.awaitingRoster],
      ));
    });

    test('reaches connected in a password group with the right password',
        () async {
      await startHost(password: 'hunter2');
      final group = await discover();

      final connected = connectedState();
      await client.join(group, password: 'hunter2');

      expect(await connected, isA<SessionConnected>());
    });

    test('fails with wrongPassword when the password is wrong', () async {
      await startHost(password: 'hunter2');
      final group = await discover();

      final failed = failedState();
      await client.join(group, password: 'nope');

      expect((await failed as SessionFailed).error, SessionError.wrongPassword);
    });

    test('fails with wrongPassword when no password is supplied', () async {
      await startHost(password: 'hunter2');
      final group = await discover();

      final failed = failedState();
      await client.join(group);

      expect((await failed as SessionFailed).error, SessionError.wrongPassword);
    });

    test('fails when the device is not reachable', () async {
      await startHost();
      final group = await discover();

      final failed = failedState();
      await client.join(group.copyWith(deviceId: 'gone'));

      expect(
        (await failed as SessionFailed).error,
        SessionError.connectionLost,
      );
    });
  });

  group('roster updates', () {
    test('reflects another member joining', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final grown = client.states.firstWhere(
        (s) => s is SessionConnected && s.roster.length == 3,
      );

      final second = FakeTransport(hub, deviceId: 'client2');
      addTearDown(second.dispose);
      final other =
          ClientSession(transport: second, displayName: 'Device 2');
      addTearDown(other.dispose);
      await other.join(group);

      expect((await grown as SessionConnected).roster.length, 3);
    });

    test('reflects the host marking a member as talking', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final talking = client.states.firstWhere(
        (s) =>
            s is SessionConnected &&
            s.roster.any((m) => m.id == HostSession.hostMemberId && m.isTalking),
      );

      await host.requestTalk();

      expect(await talking, isA<SessionConnected>());
    });
  });

  group('talk control', () {
    test('grants the floor and tells the host', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      expect(await client.requestTalk(), isTrue);
      expect(clientTransport.isTalking, isTrue);

      await Future<void>.delayed(Duration.zero);
      expect(
        (host.state as SessionConnected)
            .roster
            .firstWhere((m) => m.id == 'm2')
            .isTalking,
        isTrue,
      );
    });

    test('stopTalk clears the floor', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      await client.requestTalk();
      await client.stopTalk();

      expect(clientTransport.isTalking, isFalse);
    });

    test('refuses to talk when not connected', () async {
      expect(await client.requestTalk(), isFalse);
    });

    test('a host-revoked talk stop halts the local transport', () async {
      await startHost();
      final group = await discover();

      final peerIdFuture =
          hostTransport.events.whereType<PeerConnectedEvent>().first;
      final connected = connectedState();
      await client.join(group);
      await connected;

      final peerId = (await peerIdFuture).peerId;

      expect(await client.requestTalk(), isTrue);
      expect(clientTransport.isTalking, isTrue);

      // Simulate the host revoking the floor, exactly as
      // HostSession._onRemoteTalk does when a talk request loses the race
      // against the concurrent-talker cap (spec section 5.4): it replies
      // directly to the requester with a TalkStop naming that requester's
      // own member id.
      await hostTransport.sendControl(
        peerId,
        FrameCodec.encode(const ControlFrame.talkStop(memberId: 'm2')),
      );
      await Future<void>.delayed(Duration.zero);

      final state = client.state as SessionConnected;
      expect(
        state.roster.firstWhere((m) => m.id == 'm2').isTalking,
        isFalse,
      );
      expect(clientTransport.isTalking, isFalse);
    });
  });

  group('teardown', () {
    test('leave returns to idle and removes the member from the host',
        () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      await client.leave();
      await Future<void>.delayed(Duration.zero);

      expect(client.state, isA<SessionIdle>());
      expect((host.state as SessionConnected).roster.length, 1);
    });

    test('leave never emits a failure state', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final states = <SessionState>[];
      final sub = client.states.listen(states.add);

      await client.leave();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, isNot(contains(isA<SessionFailed>())));
      expect(states.last, isA<SessionIdle>());
    });

    test('fails with hostLeft when the host ends the group', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final failed = failedState();
      await host.stop();

      expect((await failed as SessionFailed).error, SessionError.hostLeft);
    });

    test('fails with connectionLost when the link drops unexpectedly',
        () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final failed = failedState();
      await hostTransport.dispose();

      expect(
        (await failed as SessionFailed).error,
        SessionError.connectionLost,
      );
    });
  });
}
