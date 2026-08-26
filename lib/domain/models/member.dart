import 'package:freezed_annotation/freezed_annotation.dart';

part 'member.freezed.dart';

enum MemberPresence { online, reconnecting, offline }

@freezed
abstract class Member with _$Member {
  const factory Member({
    required String id,
    required String displayName,
    @Default(false) bool isHost,
    @Default(false) bool isSelf,
    @Default(MemberPresence.online) MemberPresence presence,
    @Default(false) bool isTalking,
  }) = _Member;
}
