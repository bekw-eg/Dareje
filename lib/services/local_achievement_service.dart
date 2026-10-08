import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';

class LocalAchievementService {
  LocalAchievementService({
    required String login,
    SharedPreferencesAsync? preferences,
  }) : _storageKey = 'dareje.achievements.v1.${login.trim().toLowerCase()}',
       _providedPreferences = preferences;

  // Отдельный ключ для каждого аккаунта; выход не удаляет достижения.
  final String _storageKey;
  final SharedPreferencesAsync? _providedPreferences;
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();

  Future<List<Achievement>> load() async {
    final saved = await _preferences.getString(_storageKey);
    if (saved == null) return [];
    return (jsonDecode(saved) as List<dynamic>)
        .map((item) => Achievement.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(Achievement achievement) async {
    final achievements = await load();
    await _preferences.setString(
      _storageKey,
      jsonEncode([
        achievement.toJson(),
        ...achievements.map((item) => item.toJson()),
      ]),
    );
  }
}
