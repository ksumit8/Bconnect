import 'package:freezed_annotation/freezed_annotation.dart';

import 'discovered_group.dart';
import 'member.dart';

part 'session_state.freezed.dart';

enum JoinStep { connecting, authenticating, awaitingRoster }

enum SessionError {
  wrongPassword,
  groupFull,
  hostLeft,
  connectionLost,
  incompatibleVersion,
  bluetoothOff,
  permissionDenied,
  peripheralUnsupported,
}

@freezed
sealed class SessionState with _$SessionState {
  const factory SessionState.idle() = SessionIdle;

  const factory SessionState.discovering() = SessionDiscovering;

  const factory SessionState.joining({
    required DiscoveredGroup group,
    required JoinStep step,
  }) = SessionJoining;

  const factory SessionState.connected({
    required String groupId,
    required String groupName,
    required String myMemberId,
    required bool isHost,
    required List<Member> roster,
  }) = SessionConnected;

  const factory SessionState.failed({required SessionError error}) =
      SessionFailed;
}
