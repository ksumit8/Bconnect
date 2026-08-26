import 'dart:async';
import 'dart:typed_data';

import '../../transport/group_transport.dart';
import '../models/discovered_group.dart';
import '../models/member.dart';
import '../models/session_state.dart';
import '../protocol/control_frame.dart';
import '../protocol/frame_codec.dart';
import '../protocol/password_proof.dart';
import '../protocol/protocol_limits.dart';
import 'roster.dart';

/// Client-role state machine (spec section 5.3).
class ClientSession {
  ClientSession({
    required GroupTransport transport,
    required String displayName,
  })  : _transport = transport,
        _displayName = displayName;

  final GroupTransport _transport;
  final String _displayName;

  final StreamController<SessionState> _states =
      StreamController<SessionState>.broadcast();

  StreamSubscription<TransportEvent>? _subscription;

  SessionState _state = const SessionState.idle();
  DiscoveredGroup? _group;
  String? _peerId;
  String? _password;
  String? _myMemberId;

  /// Set once the host has ended the group, so the disconnect that follows is
  /// reported as hostLeft rather than connectionLost.
  bool _hostEnded = false;

  SessionState get state => _state;
  Stream<SessionState> get states => _states.stream;

  Future<void> join(DiscoveredGroup group, {String? password}) async {
    _group = group;
    _password = password;
    _myMemberId = null;
    _hostEnded = false;

    _subscription ??= _transport.events.listen(_onEvent);
    _setState(SessionState.joining(group: group, step: JoinStep.connecting));

    try {
      _peerId = await _transport.connect(group.deviceId);
    } on TransportException {
      _setState(const SessionState.failed(error: SessionError.connectionLost));
      return;
    }

    _setState(
      SessionState.joining(group: group, step: JoinStep.authenticating),
    );
  }

  Future<void> leave() async {
    final peerId = _peerId;
    if (peerId != null) {
      await _send(const ControlFrame.leave());
      await _transport.stopTalking();
      try {
        await _transport.disconnect(peerId);
      } on TransportException {
        // Already gone.
      }
    }

    _peerId = null;
    _myMemberId = null;
    _setState(const SessionState.idle());
  }

  /// Returns false when not connected, or when the concurrent-talker cap is
  /// already reached (spec section 5.4).
  Future<bool> requestTalk() async {
    final current = _state;
    final memberId = _myMemberId;
    if (current is! SessionConnected || memberId == null) return false;
    if (!Roster.canTalk(current.roster, memberId)) return false;

    _setTalking(memberId, true);
    await _transport.startTalking();
    await _send(ControlFrame.talkStart(memberId: memberId));

    return true;
  }

  Future<void> stopTalk() async {
    final memberId = _myMemberId;
    if (memberId == null) return;

    _setTalking(memberId, false);
    await _transport.stopTalking();
    await _send(ControlFrame.talkStop(memberId: memberId));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _states.close();
  }

  void _onEvent(TransportEvent event) {
    switch (event) {
      case ControlMessageEvent(:final peerId, :final bytes)
          when peerId == _peerId:
        _onControl(bytes);
      case PeerDisconnectedEvent(:final peerId) when peerId == _peerId:
        _onDisconnected();
      case ControlMessageEvent():
      case PeerDisconnectedEvent():
      case PeerConnectedEvent():
      case ScanResultEvent():
      case TransportErrorEvent():
        break;
    }
  }

  Future<void> _onControl(Uint8List bytes) async {
    final ControlFrame frame;
    try {
      frame = FrameCodec.decode(bytes);
    } on FrameDecodeException {
      return;
    }

    switch (frame) {
      case ChallengeFrame(:final nonce):
        await _answerChallenge(nonce);
      case JoinAcceptedFrame(:final memberId, :final roster):
        _onAccepted(memberId, roster);
      case JoinRejectedFrame(:final reason):
        _onRejected(reason);
      case RosterUpdateFrame(:final members):
        _onRoster(members);
      case TalkStartFrame(:final memberId):
        _setTalking(memberId, true);
      case TalkStopFrame(:final memberId):
        _setTalking(memberId, false);
      case LeaveFrame():
        // The host ended the group.
        _hostEnded = true;
        _setState(const SessionState.failed(error: SessionError.hostLeft));
      case PingFrame():
        await _send(const ControlFrame.pong());
      case JoinRequestFrame():
      case PongFrame():
        break;
    }
  }

  Future<void> _answerChallenge(Uint8List nonce) async {
    final password = _password;

    await _send(
      ControlFrame.joinRequest(
        version: ProtocolLimits.protocolVersion,
        displayName: _displayName,
        passwordProof: password == null || password.isEmpty
            ? Uint8List(0)
            : PasswordProof.compute(password: password, nonce: nonce),
      ),
    );

    _setState(
      SessionState.joining(group: _group!, step: JoinStep.awaitingRoster),
    );
  }

  void _onAccepted(String memberId, List<Member> roster) {
    _myMemberId = memberId;
    final group = _group!;

    _setState(
      SessionState.connected(
        groupId: group.groupId,
        groupName: group.name,
        myMemberId: memberId,
        isHost: false,
        roster: _markSelf(roster, memberId),
      ),
    );
  }

  void _onRejected(JoinRejectReason reason) {
    _setState(
      SessionState.failed(
        error: switch (reason) {
          JoinRejectReason.wrongPassword => SessionError.wrongPassword,
          JoinRejectReason.full => SessionError.groupFull,
          JoinRejectReason.incompatibleVersion =>
            SessionError.incompatibleVersion,
        },
      ),
    );
    _peerId = null;
  }

  void _onRoster(List<Member> members) {
    final current = _state;
    final memberId = _myMemberId;
    if (current is! SessionConnected || memberId == null) return;

    _setState(current.copyWith(roster: _markSelf(members, memberId)));
  }

  void _onDisconnected() {
    _peerId = null;

    if (_hostEnded || _state is SessionFailed) return;
    if (_state is SessionIdle) return;

    _setState(const SessionState.failed(error: SessionError.connectionLost));
  }

  /// The host sends `isSelf: false` for everyone, so the client marks its own
  /// entry on arrival.
  List<Member> _markSelf(List<Member> roster, String memberId) =>
      List.unmodifiable([
        for (final m in roster) m.copyWith(isSelf: m.id == memberId),
      ]);

  void _setTalking(String memberId, bool talking) {
    final current = _state;
    if (current is! SessionConnected) return;

    _setState(
      current.copyWith(
        roster: Roster.setTalking(current.roster, memberId, talking),
      ),
    );
  }

  Future<void> _send(ControlFrame frame) async {
    final peerId = _peerId;
    if (peerId == null) return;

    try {
      await _transport.sendControl(peerId, FrameCodec.encode(frame));
    } on TransportException {
      // The link dropped; _onDisconnected reports it.
    }
  }

  void _setState(SessionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
