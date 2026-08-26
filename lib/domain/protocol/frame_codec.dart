import 'dart:convert';
import 'dart:typed_data';

import '../models/member.dart';
import 'control_frame.dart';

class FrameDecodeException implements Exception {
  const FrameDecodeException(this.message);

  final String message;

  @override
  String toString() => 'FrameDecodeException: $message';
}

/// Frame type discriminators. Values are part of the wire format and must
/// never be reordered or reused.
abstract final class _FrameType {
  static const int challenge = 1;
  static const int joinRequest = 2;
  static const int joinAccepted = 3;
  static const int joinRejected = 4;
  static const int rosterUpdate = 5;
  static const int talkStart = 6;
  static const int talkStop = 7;
  static const int leave = 8;
  static const int ping = 9;
  static const int pong = 10;
}

class _Writer {
  final BytesBuilder _out = BytesBuilder();

  void uint8(int value) => _out.addByte(value);

  /// Length-prefixed so the reader never has to guess where a field ends.
  void bytes(Uint8List value) {
    uint8(value.length);
    _out.add(value);
  }

  void string(String value) => bytes(Uint8List.fromList(utf8.encode(value)));

  void member(Member m) {
    string(m.id);
    string(m.displayName);
    uint8((m.isHost ? 1 : 0) | (m.isSelf ? 2 : 0) | (m.isTalking ? 4 : 0));
    uint8(m.presence.index);
  }

  void members(List<Member> list) {
    uint8(list.length);
    list.forEach(member);
  }

  Uint8List take() => _out.takeBytes();
}

class _Reader {
  _Reader(this._data);

  final Uint8List _data;
  int _offset = 0;

  int uint8() {
    if (_offset >= _data.length) {
      throw const FrameDecodeException('unexpected end of frame');
    }
    return _data[_offset++];
  }

  Uint8List bytes() {
    final length = uint8();
    if (_offset + length > _data.length) {
      throw const FrameDecodeException('field length exceeds frame');
    }
    final value = Uint8List.fromList(
      _data.sublist(_offset, _offset + length),
    );
    _offset += length;
    return value;
  }

  String string() {
    try {
      return utf8.decode(bytes());
    } on FormatException catch (e) {
      throw FrameDecodeException('invalid UTF-8: ${e.message}');
    }
  }

  Member member() {
    final id = string();
    final displayName = string();
    final flags = uint8();
    final presenceIndex = uint8();

    if (presenceIndex >= MemberPresence.values.length) {
      throw const FrameDecodeException('unknown member presence');
    }

    return Member(
      id: id,
      displayName: displayName,
      isHost: flags & 1 != 0,
      isSelf: flags & 2 != 0,
      isTalking: flags & 4 != 0,
      presence: MemberPresence.values[presenceIndex],
    );
  }

  List<Member> members() =>
      List<Member>.generate(uint8(), (_) => member(), growable: false);
}

abstract final class FrameCodec {
  static Uint8List encode(ControlFrame frame) {
    final w = _Writer();

    switch (frame) {
      case ChallengeFrame(:final nonce):
        w.uint8(_FrameType.challenge);
        w.bytes(nonce);
      case JoinRequestFrame(
          :final version,
          :final displayName,
          :final passwordProof
        ):
        w.uint8(_FrameType.joinRequest);
        w.uint8(version);
        w.string(displayName);
        w.bytes(passwordProof);
      case JoinAcceptedFrame(:final memberId, :final roster):
        w.uint8(_FrameType.joinAccepted);
        w.string(memberId);
        w.members(roster);
      case JoinRejectedFrame(:final reason):
        w.uint8(_FrameType.joinRejected);
        w.uint8(reason.index);
      case RosterUpdateFrame(:final members):
        w.uint8(_FrameType.rosterUpdate);
        w.members(members);
      case TalkStartFrame(:final memberId):
        w.uint8(_FrameType.talkStart);
        w.string(memberId);
      case TalkStopFrame(:final memberId):
        w.uint8(_FrameType.talkStop);
        w.string(memberId);
      case LeaveFrame():
        w.uint8(_FrameType.leave);
      case PingFrame():
        w.uint8(_FrameType.ping);
      case PongFrame():
        w.uint8(_FrameType.pong);
    }

    return w.take();
  }

  static ControlFrame decode(Uint8List data) {
    final r = _Reader(data);

    switch (r.uint8()) {
      case _FrameType.challenge:
        return ControlFrame.challenge(nonce: r.bytes());
      case _FrameType.joinRequest:
        return ControlFrame.joinRequest(
          version: r.uint8(),
          displayName: r.string(),
          passwordProof: r.bytes(),
        );
      case _FrameType.joinAccepted:
        return ControlFrame.joinAccepted(
          memberId: r.string(),
          roster: r.members(),
        );
      case _FrameType.joinRejected:
        final index = r.uint8();
        if (index >= JoinRejectReason.values.length) {
          throw const FrameDecodeException('unknown rejection reason');
        }
        return ControlFrame.joinRejected(
          reason: JoinRejectReason.values[index],
        );
      case _FrameType.rosterUpdate:
        return ControlFrame.rosterUpdate(members: r.members());
      case _FrameType.talkStart:
        return ControlFrame.talkStart(memberId: r.string());
      case _FrameType.talkStop:
        return ControlFrame.talkStop(memberId: r.string());
      case _FrameType.leave:
        return const ControlFrame.leave();
      case _FrameType.ping:
        return const ControlFrame.ping();
      case _FrameType.pong:
        return const ControlFrame.pong();
      case final unknown:
        throw FrameDecodeException('unknown frame type $unknown');
    }
  }
}
