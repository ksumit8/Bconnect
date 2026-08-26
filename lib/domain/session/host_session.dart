import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../transport/group_transport.dart';
import '../models/group_config.dart';
import '../models/member.dart';
import '../models/session_state.dart';
import '../protocol/control_frame.dart';
import '../protocol/frame_codec.dart';
import '../protocol/password_proof.dart';
import '../protocol/protocol_limits.dart';
import 'roster.dart';

/// Host-role state machine (spec section 5.3).
///
/// Owns the roster, verifies join requests, and relays talk state. It never
/// touches audio bytes: the transport handles those natively.
class HostSession {
  HostSession({
    required GroupTransport transport,
    required GroupConfig config,
    required String hostDisplayName,
    Random? random,
  })  : _transport = transport,
        _config = config,
        _hostDisplayName = hostDisplayName,
        _random = random ?? Random.secure();

  static const String hostMemberId = 'm1';

  final GroupTransport _transport;
  final GroupConfig _config;
  final String _hostDisplayName;
  final Random _random;

  final StreamController<SessionState> _states =
      StreamController<SessionState>.broadcast();

  /// Nonce issued to each connected peer, pending its join request.
  final Map<String, Uint8List> _challenges = {};

  /// Member id for each peer that has completed the handshake.
  final Map<String, String> _memberIdByPeer = {};

  StreamSubscription<TransportEvent>? _subscription;

  SessionState _state = const SessionState.idle();
  int _groupId = 0;
  int _nextMemberNumber = 2;

  SessionState get state => _state;
  Stream<SessionState> get states => _states.stream;
  int get groupId => _groupId;

  Future<void> start() async {
    _groupId = _random.nextInt(0x10000);
    _subscription = _transport.events.listen(_onEvent);

    _setState(
      SessionState.connected(
        groupId: _groupId.toRadixString(16).padLeft(4, '0'),
        groupName: _config.name,
        myMemberId: hostMemberId,
        isHost: true,
        roster: [
          Member(
            id: hostMemberId,
            displayName: _hostDisplayName,
            isHost: true,
            isSelf: true,
          ),
        ],
      ),
    );

    await _transport.startAdvertising(
      groupName: _config.name,
      groupId: _groupId,
      memberCount: 1,
      isLocked: _config.isLocked,
      isFull: false,
    );
  }

  Future<void> stop() async {
    for (final peerId in _memberIdByPeer.keys.toList()) {
      await _send(peerId, const ControlFrame.leave());
      try {
        await _transport.disconnect(peerId);
      } on TransportException {
        // The peer is already gone (it dropped on its own before we got to
        // it); that is fine during teardown.
      }
    }

    _memberIdByPeer.clear();
    _challenges.clear();

    await _transport.stopTalking();
    await _transport.stopAdvertising();

    _setState(const SessionState.idle());
  }

  /// Returns false when the concurrent-talker cap is already reached
  /// (spec section 5.4).
  Future<bool> requestTalk() async {
    final current = _state;
    if (current is! SessionConnected) return false;
    if (!Roster.canTalk(current.roster, hostMemberId)) return false;

    _setRosterTalking(hostMemberId, true);
    await _transport.startTalking();
    await _broadcast(const ControlFrame.talkStart(memberId: hostMemberId));

    return true;
  }

  Future<void> stopTalk() async {
    _setRosterTalking(hostMemberId, false);
    await _transport.stopTalking();
    await _broadcast(const ControlFrame.talkStop(memberId: hostMemberId));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _states.close();
  }

  void _onEvent(TransportEvent event) {
    switch (event) {
      case PeerConnectedEvent(:final peerId):
        _challenge(peerId);
      case PeerDisconnectedEvent(:final peerId):
        _removePeer(peerId);
      case ControlMessageEvent(:final peerId, :final bytes):
        _onControl(peerId, bytes);
      case ScanResultEvent():
      case TransportErrorEvent():
        break;
    }
  }

  Future<void> _challenge(String peerId) async {
    final nonce = PasswordProof.generateNonce(_random);
    _challenges[peerId] = nonce;
    await _send(peerId, ControlFrame.challenge(nonce: nonce));
  }

  Future<void> _onControl(String peerId, Uint8List bytes) async {
    final ControlFrame frame;
    try {
      frame = FrameCodec.decode(bytes);
    } on FrameDecodeException {
      return; // Ignore malformed traffic rather than tearing down the group.
    }

    switch (frame) {
      case JoinRequestFrame(:final version, :final displayName, :final passwordProof):
        await _onJoinRequest(peerId, version, displayName, passwordProof);
      case TalkStartFrame(:final memberId):
        await _onRemoteTalk(peerId, memberId, true);
      case TalkStopFrame(:final memberId):
        await _onRemoteTalk(peerId, memberId, false);
      case LeaveFrame():
        _removePeer(peerId);
        await _transport.disconnect(peerId);
      case PingFrame():
        await _send(peerId, const ControlFrame.pong());
      case ChallengeFrame():
      case JoinAcceptedFrame():
      case JoinRejectedFrame():
      case RosterUpdateFrame():
      case PongFrame():
        break; // Host-bound peers never send these.
    }
  }

  Future<void> _onJoinRequest(
    String peerId,
    int version,
    String displayName,
    Uint8List proof,
  ) async {
    // A peer that has already completed the handshake gets nothing: a
    // well-behaved client that retries should not be told to disconnect,
    // and no flow in this design legitimately re-handshakes on an existing
    // connection. Without this guard, a repeat request would mint a second,
    // unreachable roster entry for the same connection (spec section 5.3).
    if (_memberIdByPeer.containsKey(peerId)) return;

    final current = _state;
    if (current is! SessionConnected) return;

    Future<void> reject(JoinRejectReason reason) async {
      await _send(peerId, ControlFrame.joinRejected(reason: reason));
      await _transport.disconnect(peerId);
      _challenges.remove(peerId);
    }

    if (version != ProtocolLimits.protocolVersion) {
      return reject(JoinRejectReason.incompatibleVersion);
    }

    if (Roster.isFull(current.roster)) {
      return reject(JoinRejectReason.full);
    }

    if (_config.isLocked) {
      final nonce = _challenges[peerId];
      if (nonce == null ||
          !PasswordProof.verify(
            password: _config.password!,
            nonce: nonce,
            proof: proof,
          )) {
        return reject(JoinRejectReason.wrongPassword);
      }
    }

    final memberId = 'm${_nextMemberNumber++}';
    _memberIdByPeer[peerId] = memberId;
    _challenges.remove(peerId);

    final roster = Roster.add(
      current.roster,
      Member(id: memberId, displayName: displayName),
    );
    _setState(current.copyWith(roster: roster));

    await _send(
      peerId,
      ControlFrame.joinAccepted(memberId: memberId, roster: roster),
    );
    await _broadcast(
      ControlFrame.rosterUpdate(members: roster),
      except: peerId,
    );
    await _updateAdvertisement(roster);
  }

  Future<void> _onRemoteTalk(
    String peerId,
    String memberId,
    bool talking,
  ) async {
    // A member may only change its own talk state.
    if (_memberIdByPeer[peerId] != memberId) return;

    final current = _state;
    if (current is! SessionConnected) return;

    if (talking && !Roster.canTalk(current.roster, memberId)) {
      // Floor busy: tell the requester to stand down (spec section 5.4).
      await _send(peerId, ControlFrame.talkStop(memberId: memberId));
      return;
    }

    _setRosterTalking(memberId, talking);
    await _broadcast(
      talking
          ? ControlFrame.talkStart(memberId: memberId)
          : ControlFrame.talkStop(memberId: memberId),
      except: peerId,
    );
  }

  void _removePeer(String peerId) {
    final memberId = _memberIdByPeer.remove(peerId);
    _challenges.remove(peerId);
    if (memberId == null) return;

    final current = _state;
    if (current is! SessionConnected) return;

    final roster = Roster.remove(current.roster, memberId);
    _setState(current.copyWith(roster: roster));

    unawaited(_broadcast(ControlFrame.rosterUpdate(members: roster)));
    unawaited(_updateAdvertisement(roster));
  }

  void _setRosterTalking(String memberId, bool talking) {
    final current = _state;
    if (current is! SessionConnected) return;

    _setState(
      current.copyWith(
        roster: Roster.setTalking(current.roster, memberId, talking),
      ),
    );
  }

  Future<void> _updateAdvertisement(List<Member> roster) async {
    try {
      await _transport.updateAdvertisement(
        memberCount: roster.length,
        isFull: Roster.isFull(roster),
      );
    } on TransportException {
      // Advertising may already have stopped; nothing to update.
    }
  }

  Future<void> _send(String peerId, ControlFrame frame) async {
    try {
      await _transport.sendControl(peerId, FrameCodec.encode(frame));
    } on TransportException {
      // The peer vanished mid-send; _removePeer handles the disconnect event.
    }
  }

  Future<void> _broadcast(ControlFrame frame, {String? except}) async {
    for (final peerId in _memberIdByPeer.keys.toList()) {
      if (peerId == except) continue;
      await _send(peerId, frame);
    }
  }

  void _setState(SessionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
