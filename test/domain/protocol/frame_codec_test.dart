import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/member.dart';
import 'package:bconnect/domain/protocol/control_frame.dart';
import 'package:bconnect/domain/protocol/frame_codec.dart';

void main() {
  void expectRoundTrip(ControlFrame frame) {
    expect(FrameCodec.decode(FrameCodec.encode(frame)), equals(frame));
  }

  test('round-trips a challenge', () {
    expectRoundTrip(
      ControlFrame.challenge(
        nonce: Uint8List.fromList(List.generate(16, (i) => i)),
      ),
    );
  });

  test('round-trips a join request', () {
    expectRoundTrip(
      ControlFrame.joinRequest(
        version: 1,
        displayName: 'Device 1',
        passwordProof: Uint8List.fromList(List.filled(16, 7)),
      ),
    );
  });

  test('round-trips a join request with an empty proof for an open group', () {
    expectRoundTrip(
      ControlFrame.joinRequest(
        version: 1,
        displayName: 'Device 1',
        passwordProof: Uint8List(0),
      ),
    );
  });

  test('round-trips a join acceptance carrying a full roster', () {
    expectRoundTrip(
      ControlFrame.joinAccepted(
        memberId: 'm2',
        roster: const [
          Member(id: 'm1', displayName: 'You', isHost: true),
          Member(
            id: 'm2',
            displayName: 'Device 1',
            presence: MemberPresence.reconnecting,
            isTalking: true,
          ),
        ],
      ),
    );
  });

  test('round-trips every rejection reason', () {
    for (final reason in JoinRejectReason.values) {
      expectRoundTrip(ControlFrame.joinRejected(reason: reason));
    }
  });

  test('round-trips a roster update', () {
    expectRoundTrip(
      ControlFrame.rosterUpdate(
        members: const [Member(id: 'm1', displayName: 'You', isHost: true)],
      ),
    );
  });

  test('round-trips an empty roster', () {
    expectRoundTrip(const ControlFrame.rosterUpdate(members: []));
  });

  test('round-trips talk start and stop', () {
    expectRoundTrip(const ControlFrame.talkStart(memberId: 'm3'));
    expectRoundTrip(const ControlFrame.talkStop(memberId: 'm3'));
  });

  test('round-trips the payload-free frames', () {
    expectRoundTrip(const ControlFrame.leave());
    expectRoundTrip(const ControlFrame.ping());
    expectRoundTrip(const ControlFrame.pong());
  });

  test('preserves multi-byte display names', () {
    expectRoundTrip(
      ControlFrame.joinRequest(
        version: 1,
        displayName: 'Grüße 🎧',
        passwordProof: Uint8List(0),
      ),
    );
  });

  test('throws on an empty buffer', () {
    expect(
      () => FrameCodec.decode(Uint8List(0)),
      throwsA(isA<FrameDecodeException>()),
    );
  });

  test('throws on an unknown frame type', () {
    expect(
      () => FrameCodec.decode(Uint8List.fromList([250])),
      throwsA(isA<FrameDecodeException>()),
    );
  });

  test('throws on a truncated frame rather than reading past the end', () {
    final full = FrameCodec.encode(
      const ControlFrame.talkStart(memberId: 'm3'),
    );

    expect(
      () => FrameCodec.decode(full.sublist(0, full.length - 1)),
      throwsA(isA<FrameDecodeException>()),
    );
  });

  test('round-trips a member with isSelf true', () {
    expectRoundTrip(
      ControlFrame.rosterUpdate(
        members: const [Member(id: 'm1', displayName: 'You', isSelf: true)],
      ),
    );
  });

  test(
    'throws when decoding a joinRejected with an out-of-range reason index',
    () {
      final full = FrameCodec.encode(
        const ControlFrame.joinRejected(reason: JoinRejectReason.full),
      );
      // Overwrite the reason byte (last byte) with an index beyond the enum.
      final tampered = Uint8List.fromList(full);
      tampered[tampered.length - 1] = 99;

      expect(
        () => FrameCodec.decode(tampered),
        throwsA(isA<FrameDecodeException>()),
      );
    },
  );

  test('throws on invalid UTF-8 rather than an uncaught FormatException', () {
    // Frame type 6 (talkStart) followed by a length-1 string field
    // containing an invalid UTF-8 lead byte.
    final invalid = Uint8List.fromList([6, 1, 0xFF]);

    expect(
      () => FrameCodec.decode(invalid),
      throwsA(isA<FrameDecodeException>()),
    );
  });

  test('throws when encoding a string field over 255 UTF-8 bytes', () {
    expect(
      () => FrameCodec.encode(ControlFrame.talkStart(memberId: 'x' * 300)),
      throwsA(isA<FrameEncodeException>()),
    );
  });

  test('throws when encoding a roster update with more than 255 members', () {
    final members = List<Member>.generate(
      256,
      (i) => Member(id: 'm$i', displayName: 'Device $i'),
    );

    expect(
      () => FrameCodec.encode(ControlFrame.rosterUpdate(members: members)),
      throwsA(isA<FrameEncodeException>()),
    );
  });

  test('round-trips a string field of exactly 255 bytes', () {
    expectRoundTrip(ControlFrame.talkStart(memberId: 'x' * 255));
  });

  test('throws when decoding a valid frame with extra trailing bytes', () {
    final full = FrameCodec.encode(
      const ControlFrame.talkStart(memberId: 'm3'),
    );
    final withTrailingByte = Uint8List.fromList([...full, 0]);

    expect(
      () => FrameCodec.decode(withTrailingByte),
      throwsA(isA<FrameDecodeException>()),
    );
  });
}
