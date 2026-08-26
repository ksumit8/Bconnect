/// An entry in the "Your Groups" list on the home screen.
class RecentGroup {
  const RecentGroup({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.lastJoined,
  });

  final String groupId;
  final String name;
  final int memberCount;
  final DateTime lastJoined;

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'memberCount': memberCount,
        'lastJoined': lastJoined.toIso8601String(),
      };

  static RecentGroup fromJson(Map<String, dynamic> json) => RecentGroup(
        groupId: json['groupId'] as String,
        name: json['name'] as String,
        memberCount: json['memberCount'] as int,
        lastJoined: DateTime.parse(json['lastJoined'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is RecentGroup &&
      other.groupId == groupId &&
      other.name == name &&
      other.memberCount == memberCount &&
      other.lastJoined == lastJoined;

  @override
  int get hashCode => Object.hash(groupId, name, memberCount, lastJoined);
}
