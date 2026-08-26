import 'dart:convert';
import 'dart:typed_data';

import '../models/member.dart';
import 'control_frame.dart';
import 'protocol_limits.dart';

class FrameDecodeException implements Exception {
  const FrameDecodeException(this.message);

  final String message;

  @override
  String toString() => 'FrameDecodeException: $message';
}

class FrameEncodeException implements Exception {
  const FrameEncodeException(this.message);

  final String message;

  @override
  String toString() => 'FrameEncodeException: $message';
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
    if (value.length > ProtocolLimits.maxFieldBytes) {
      throw FrameEncodeException(
        'field length ${value.length} exceeds the maximum of '
        '${ProtocolLimits.maxFieldBytes} bytes',
      );
    }
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
    if (list.length > ProtocolLimits.maxFieldBytes) {
      throw FrameEncodeException(
        'member count ${list.length} exceeds the maximum of '
        '${ProtocolLimits.maxFieldBytes}',
      );
    }
    uint8(list.length);
    list.forEach(member);
  }

  Uint8List take() => _out.takeBytes();
}

class _Reader {
  _Reader(this._data);

  final Uint8List _data;
  int _offset = 0;

  bool get isExhausted => _offset >= _data.length;

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
    final value = Uint8List.fromList(_data.sublist(_offset, _offset + length));
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
        :final passwordProof,
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

    final frame = switch (r.uint8()) {
      _FrameType.challenge => ControlFrame.challenge(nonce: r.bytes()),
      _FrameType.joinRequest => ControlFrame.joinRequest(
        version: r.uint8(),
        displayName: r.string(),
        passwordProof: r.bytes(),
      ),
      _FrameType.joinAccepted => ControlFrame.joinAccepted(
        memberId: r.string(),
        roster: r.members(),
      ),
      _FrameType.joinRejected => _decodeJoinRejected(r),
      _FrameType.rosterUpdate => ControlFrame.rosterUpdate(
        members: r.members(),
      ),
      _FrameType.talkStart => ControlFrame.talkStart(memberId: r.string()),
      _FrameType.talkStop => ControlFrame.talkStop(memberId: r.string()),
      _FrameType.leave => const ControlFrame.leave(),
      _FrameType.ping => const ControlFrame.ping(),
      _FrameType.pong => const ControlFrame.pong(),
      final unknown => throw FrameDecodeException(
        'unknown frame type $unknown',
      ),
    };

    if (!r.isExhausted) {
      throw const FrameDecodeException('trailing bytes after frame');
    }

    return frame;
  }

  static ControlFrame _decodeJoinRejected(_Reader r) {
    final index = r.uint8();
    if (index >= JoinRejectReason.values.length) {
      throw const FrameDecodeException('unknown rejection reason');
    }
    return ControlFrame.joinRejected(reason: JoinRejectReason.values[index]);
  }
}
