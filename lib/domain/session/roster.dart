import '../models/member.dart';
import '../protocol/protocol_limits.dart';

/// Pure roster transformations. Every method returns a new list; none mutate
/// their input, so these are safe to call directly from a Notifier.
abstract final class Roster {
  /// Appends [member], or replaces an existing entry with the same id.
  static List<Member> add(List<Member> current, Member member) {
    final index = current.indexWhere((m) => m.id == member.id);
    final next = List<Member>.of(current);

    if (index == -1) {
      next.add(member);
    } else {
      next[index] = member;
    }
    return List.unmodifiable(next);
  }

  static List<Member> remove(List<Member> current, String memberId) =>
      List.unmodifiable(current.where((m) => m.id != memberId));

  static List<Member> setTalking(
    List<Member> current,
    String memberId,
    bool talking,
  ) =>
      _update(current, memberId, (m) => m.copyWith(isTalking: talking));

  static List<Member> setPresence(
    List<Member> current,
    String memberId,
    MemberPresence presence,
  ) =>
      _update(current, memberId, (m) => m.copyWith(presence: presence));

  static int talkingCount(List<Member> current) =>
      current.where((m) => m.isTalking).length;

  static bool isFull(List<Member> current) =>
      current.length >= ProtocolLimits.maxMembers;

  /// Whether [memberId] may start transmitting (spec section 5.4). A member
  /// already holding the floor is always allowed, so re-asserting talk does
  /// not fail at the cap.
  static bool canTalk(List<Member> current, String memberId) {
    final already =
        current.any((m) => m.id == memberId && m.isTalking);
    if (already) return true;

    return talkingCount(current) < ProtocolLimits.maxConcurrentTalkers;
  }

  static List<Member> _update(
    List<Member> current,
    String memberId,
    Member Function(Member) transform,
  ) =>
      List.unmodifiable([
        for (final m in current) m.id == memberId ? transform(m) : m,
      ]);
}
