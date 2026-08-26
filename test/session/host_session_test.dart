import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/protocol/control_frame.dart';
import 'package:bconnect/domain/protocol/frame_codec.dart';
import 'package:bconnect/domain/protocol/password_proof.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/domain/session/host_session.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
  late FakeHub hub;
  late FakeTransport hostTransport;
  late FakeTransport clientTransport;
  late HostSession session;

  setUp(() {
    hub = FakeHub();
    hostTransport = FakeTransport(hub, deviceId: 'host');
    clientTransport = FakeTransport(hub, deviceId: 'client');
  });

  tearDown(() async {
    await session.dispose();
    await hostTransport.dispose();
    await clientTransport.dispose();
  });

  HostSession build({String? password}) => session = HostSession(
        transport: hostTransport,
        config: GroupConfig(name: 'Team Alpha', password: password),
        hostDisplayName: 'You',
        random: Random(7),
      );

  /// Reads control frames arriving at the client.
  Stream<ControlFrame> clientFrames() => clientTransport.events
      .whereType<ControlMessageEvent>()
      .map((e) => FrameCodec.decode(e.bytes));

  Future<void> sendToHost(String peerId, ControlFrame frame) =>
      clientTransport.sendControl(peerId, FrameCodec.encode(frame));

  group('start', () {
    test('enters connected with only the host in the roster', () async {
      await build().start();

      final state = session.state as SessionConnected;

      expect(state.groupName, 'Team Alpha');
      expect(state.isHost, isTrue);
      expect(state.myMemberId, HostSession.hostMemberId);
      expect(state.roster.length, 1);
      expect(state.roster.single.isHost, isTrue);
      expect(state.roster.single.isSelf, isTrue);
      expect(state.roster.single.displayName, 'You');
    });

    test('advertises the group so a scanner can find it', () async {
      await build(password: 'hunter2').start();

      final found = clientTransport.events.whereType<ScanResultEvent>().first;
      await clientTransport.startScan();

      final group = (await found).group;

      expect(group.name, 'Team Alpha');
      expect(group.isLocked, isTrue);
      expect(group.memberCount, 1);
    });
  });

  group('join handshake', () {
    test('challenges a peer as soon as it connects', () async {
      await build().start();

      final challenge = clientFrames().first;
      await clientTransport.connect('host');

      expect(await challenge, isA<ChallengeFrame>());
      expect(
        ((await challenge) as ChallengeFrame).nonce.length,
        ProtocolLimits.nonceLength,
      );
    });

    test('accepts a join into an open group with an empty proof', () async {
      await build().start();

      final frames = clientFrames();
      final challenge = frames.first; // subscribe before connecting, or the
      // synchronously-delivered challenge is lost on this broadcast stream.
      final peerId = await clientTransport.connect('host');

      await challenge;
      final accepted = frames.whereType<JoinAcceptedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: Uint8List(0),
        ),
      );

      final frame = await accepted;

      expect(frame.memberId, 'm2');
      expect(frame.roster.length, 2);
      expect((session.state as SessionConnected).roster.length, 2);
    });

    test('accepts a correct password proof', () async {
      await build(password: 'hunter2').start();

      final frames = clientFrames();
      final challengeFuture = frames.first; // subscribe before connecting.
      final peerId = await clientTransport.connect('host');

      final challenge = (await challengeFuture) as ChallengeFrame;
      final accepted = frames.whereType<JoinAcceptedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: PasswordProof.compute(
            password: 'hunter2',
            nonce: challenge.nonce,
          ),
        ),
      );

      expect((await accepted).memberId, 'm2');
    });

    test('rejects an incorrect password proof', () async {
      await build(password: 'hunter2').start();

      final frames = clientFrames();
      final challengeFuture = frames.first; // subscribe before connecting.
      final peerId = await clientTransport.connect('host');

      final challenge = (await challengeFuture) as ChallengeFrame;
      final rejected = frames.whereType<JoinRejectedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: PasswordProof.compute(
            password: 'wrong',
            nonce: challenge.nonce,
          ),
        ),
      );

      expect((await rejected).reason, JoinRejectReason.wrongPassword);
      expect((session.state as SessionConnected).roster.length, 1);
    });

    test('rejects a mismatched protocol version', () async {
      await build().start();

      final frames = clientFrames();
      final challenge = frames.first; // subscribe before connecting.
      final peerId = await clientTransport.connect('host');

      await challenge;
      final rejected = frames.whereType<JoinRejectedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion + 1,
          displayName: 'Device 1',
          passwordProof: Uint8List(0),
        ),
      );

      expect((await rejected).reason, JoinRejectReason.incompatibleVersion);
    });

    test('rejects a join once the group is full', () async {
      await build().start();

      // Fill every remaining slot.
      final extras = <FakeTransport>[];
      for (var i = 0; i < ProtocolLimits.maxMembers - 1; i++) {
        final t = FakeTransport(hub, deviceId: 'extra$i');
        extras.add(t);
        final frames =
            t.events.whereType<ControlMessageEvent>().map((e) => FrameCodec.decode(e.bytes));
        final accepted = frames.whereType<JoinAcceptedFrame>().first;
        final peerId = await t.connect('host');
        await t.sendControl(
          peerId,
          FrameCodec.encode(ControlFrame.joinRequest(
            version: ProtocolLimits.protocolVersion,
            displayName: 'Extra $i',
            passwordProof: Uint8List(0),
          )),
        );
        await accepted;
      }
      addTearDown(() async {
        for (final t in extras) {
          await t.dispose();
        }
      });

      expect((session.state as SessionConnected).roster.length,
          ProtocolLimits.maxMembers);

      final frames = clientFrames();
      final challenge = frames.first; // subscribe before connecting.
      final peerId = await clientTransport.connect('host');
      await challenge;
      final rejected = frames.whereType<JoinRejectedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'One Too Many',
          passwordProof: Uint8List(0),
        ),
      );

      expect((await rejected).reason, JoinRejectReason.full);
    });
  });

  group('membership changes', () {
    Future<String> joinClient() async {
      final frames = clientFrames();
      final challenge = frames.first; // subscribe before connecting.
      final peerId = await clientTransport.connect('host');
      await challenge;
      final accepted = frames.whereType<JoinAcceptedFrame>().first;
      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: Uint8List(0),
        ),
      );
      await accepted;
      return peerId;
    }

    test('removes a member that sends leave', () async {
      await build().start();
      final peerId = await joinClient();

      await sendToHost(peerId, const ControlFrame.leave());
      await Future<void>.delayed(Duration.zero);

      expect((session.state as SessionConnected).roster.length, 1);
    });

    test('removes a member that disconnects', () async {
      await build().start();
      final peerId = await joinClient();

      await clientTransport.disconnect(peerId);
      await Future<void>.delayed(Duration.zero);

      expect((session.state as SessionConnected).roster.length, 1);
    });

    test('marks a member talking and clears it again', () async {
      await build().start();
      final peerId = await joinClient();

      await sendToHost(peerId, const ControlFrame.talkStart(memberId: 'm2'));
      await Future<void>.delayed(Duration.zero);
      expect(
        (session.state as SessionConnected)
            .roster
            .firstWhere((m) => m.id == 'm2')
            .isTalking,
        isTrue,
      );

      await sendToHost(peerId, const ControlFrame.talkStop(memberId: 'm2'));
      await Future<void>.delayed(Duration.zero);
      expect(
        (session.state as SessionConnected)
            .roster
            .firstWhere((m) => m.id == 'm2')
            .isTalking,
        isFalse,
      );
    });

    test('answers a ping with a pong', () async {
      await build().start();
      final peerId = await joinClient();

      final pong = clientFrames().whereType<PongFrame>().first;
      await sendToHost(peerId, const ControlFrame.ping());

      expect(await pong, isA<PongFrame>());
    });
  });

  group('talk control', () {
    test('grants the floor below the concurrent cap', () async {
      await build().start();

      expect(await session.requestTalk(), isTrue);
      expect(hostTransport.isTalking, isTrue);
    });

    test('refuses the floor once the cap is reached', () async {
      await build().start();

      // Occupy every slot with other members.
      final extras = <FakeTransport>[];
      for (var i = 0; i < ProtocolLimits.maxConcurrentTalkers; i++) {
        final t = FakeTransport(hub, deviceId: 'talker$i');
        extras.add(t);
        final frames =
            t.events.whereType<ControlMessageEvent>().map((e) => FrameCodec.decode(e.bytes));
        final accepted = frames.whereType<JoinAcceptedFrame>().first;
        final peerId = await t.connect('host');
        await t.sendControl(
          peerId,
          FrameCodec.encode(ControlFrame.joinRequest(
            version: ProtocolLimits.protocolVersion,
            displayName: 'Talker $i',
            passwordProof: Uint8List(0),
          )),
        );
        final memberId = (await accepted).memberId;
        await t.sendControl(
          peerId,
          FrameCodec.encode(ControlFrame.talkStart(memberId: memberId)),
        );
      }
      addTearDown(() async {
        for (final t in extras) {
          await t.dispose();
        }
      });
      await Future<void>.delayed(Duration.zero);

      expect(await session.requestTalk(), isFalse);
      expect(hostTransport.isTalking, isFalse);
    });

    test('stopTalk clears the talking flag', () async {
      await build().start();
      await session.requestTalk();

      await session.stopTalk();

      expect(hostTransport.isTalking, isFalse);
      expect(
        (session.state as SessionConnected)
            .roster
            .firstWhere((m) => m.id == HostSession.hostMemberId)
            .isTalking,
        isFalse,
      );
    });
  });

  group('stop', () {
    test('tells members the group ended and returns to idle', () async {
      await build().start();

      final frames = clientFrames();
      final challenge = frames.first; // subscribe before connecting.
      final peerId = await clientTransport.connect('host');
      await challenge;
      final accepted = frames.whereType<JoinAcceptedFrame>().first;
      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: Uint8List(0),
        ),
      );
      await accepted;

      final leave = frames.whereType<LeaveFrame>().first;
      await session.stop();

      expect(await leave, isA<LeaveFrame>());
      expect(session.state, isA<SessionIdle>());
    });
  });
}
