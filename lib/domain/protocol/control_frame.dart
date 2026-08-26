import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/member.dart';

part 'control_frame.freezed.dart';

enum JoinRejectReason { wrongPassword, full, incompatibleVersion }

/// Control-plane messages (spec section 5.3).
///
/// Audio frames are deliberately absent: they never cross the Dart boundary
/// (spec section 3.5).
@freezed
sealed class ControlFrame with _$ControlFrame {
  /// Host to client on connect, carrying the nonce for the password proof.
  const factory ControlFrame.challenge({
    required Uint8List nonce,
  }) = ChallengeFrame;

  /// An empty [passwordProof] is sent when joining an open group.
  const factory ControlFrame.joinRequest({
    required int version,
    required String displayName,
    required Uint8List passwordProof,
  }) = JoinRequestFrame;

  const factory ControlFrame.joinAccepted({
    required String memberId,
    required List<Member> roster,
  }) = JoinAcceptedFrame;

  const factory ControlFrame.joinRejected({
    required JoinRejectReason reason,
  }) = JoinRejectedFrame;

  const factory ControlFrame.rosterUpdate({
    required List<Member> members,
  }) = RosterUpdateFrame;

  const factory ControlFrame.talkStart({required String memberId}) =
      TalkStartFrame;

  const factory ControlFrame.talkStop({required String memberId}) =
      TalkStopFrame;

  const factory ControlFrame.leave() = LeaveFrame;
  const factory ControlFrame.ping() = PingFrame;
  const factory ControlFrame.pong() = PongFrame;
}
