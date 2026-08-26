import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kDefaultDisplayName = 'My Device';
const String _key = 'display_name';

class DisplayNameController extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);

    return (stored == null || stored.trim().isEmpty)
        ? kDefaultDisplayName
        : stored;
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);

    state = AsyncData(trimmed);
  }
}

final displayNameProvider =
    AsyncNotifierProvider<DisplayNameController, String>(
  DisplayNameController.new,
);
