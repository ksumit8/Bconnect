import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/recent_group.dart';
import 'transport_provider.dart';

const int _maxRecentGroups = 5;
const String _key = 'recent_groups';

class RecentGroupsController extends AsyncNotifier<List<RecentGroup>> {
  @override
  Future<List<RecentGroup>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? const [];

    return List.unmodifiable([
      for (final entry in stored)
        RecentGroup.fromJson(jsonDecode(entry) as Map<String, dynamic>),
    ]);
  }

  /// Adds [groupId] to the front of the list, replacing any earlier entry for
  /// the same group.
  Future<void> record({
    required String groupId,
    required String name,
    required int memberCount,
  }) async {
    // Await our own build: calling record() before the persisted list has
    // loaded would otherwise read state.value as null and overwrite the
    // stored list with just this entry.
    final current = await future;

    final next = <RecentGroup>[
      RecentGroup(
        groupId: groupId,
        name: name,
        memberCount: memberCount,
        lastJoined: ref.read(clockProvider)(),
      ),
      ...current.where((g) => g.groupId != groupId),
    ].take(_maxRecentGroups).toList();

    await _persist(next);
  }

  Future<void> clear() => _persist(const []);

  Future<void> _persist(List<RecentGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      [for (final g in groups) jsonEncode(g.toJson())],
    );

    state = AsyncData(List.unmodifiable(groups));
  }
}

final recentGroupsProvider =
    AsyncNotifierProvider<RecentGroupsController, List<RecentGroup>>(
  RecentGroupsController.new,
);
