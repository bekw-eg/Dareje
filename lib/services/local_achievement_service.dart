import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/achievement_snapshot.dart';
import '../models/progress_history_entry.dart';
import 'progress_history_service.dart';

class LocalAchievementService {
  LocalAchievementService({
    required String login,
    SharedPreferencesAsync? preferences,
    DateTime Function()? clock,
  }) : _account = login.trim().toLowerCase(),
       _providedPreferences = preferences,
       _clock = clock ?? DateTime.now;

  // Отдельный ключ для каждого аккаунта; выход не удаляет достижения.
  final String _account;
  String get _storageKey => 'dareje.achievements.v2.$_account';
  String get _legacyKey => 'dareje.achievements.v1.$_account';
  final SharedPreferencesAsync? _providedPreferences;
  final DateTime Function() _clock;
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();

  final _historyService = ProgressHistoryService();

  // Очередь на аккаунт защищает от параллельных сохранений в одном приложении,
  // включая разные экземпляры сервиса. Не является межвкладочной блокировкой.
  static final _writes = <String, Future<void>>{};

  Future<List<Achievement>> load() async => (await loadSnapshot()).achievements;

  Future<AchievementSnapshot> loadSnapshot() async {
    final saved = await _preferences.getString(_storageKey);
    if (saved != null) {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      if (json['version'] != 2)
        throw const FormatException('Unsupported achievement storage');
      return AchievementSnapshot(
        achievements: _readAchievements(json['achievements'] as List<dynamic>),
        history: (json['history'] as List<dynamic>)
            .map(
              (item) =>
                  ProgressHistoryEntry.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
    }
    final legacy = await _preferences.getString(_legacyKey);
    return AchievementSnapshot(
      achievements: legacy == null
          ? []
          : _readAchievements(jsonDecode(legacy) as List<dynamic>),
      history: [],
    );
  }

  List<Achievement> _readAchievements(List<dynamic> json) => json
      .map((item) => Achievement.fromJson(item as Map<String, dynamic>))
      .toList();

  Future<void> add(Achievement achievement) async {
    final previous = _writes[_storageKey] ?? Future<void>.value();
    final operation = previous.then((_) => _add(achievement));
    // Сбой не блокирует следующую попытку; вызывающий всё равно получает ошибку.
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _writes[_storageKey] = settled;
    try {
      await operation;
    } finally {
      if (identical(_writes[_storageKey], settled)) _writes.remove(_storageKey);
    }
  }

  Future<void> _add(Achievement achievement) async {
    if (achievement.id == null)
      throw ArgumentError('New achievements require an ID');
    final snapshot = await loadSnapshot();
    if (snapshot.achievements.any((item) => item.id == achievement.id)) return;
    final event = _historyService.recordAddition(
      before: snapshot.achievements,
      achievement: achievement,
      timestamp: _clock(),
    );
    // Одна запись: достижение и наблюдаемое изменение либо сохранятся вместе,
    // либо вместе останутся несохранёнными. Старые данные v1 не удаляем.
    await _preferences.setString(
      _storageKey,
      jsonEncode({
        'version': 2,
        'achievements': [
          achievement.toJson(),
          ...snapshot.achievements.map((item) => item.toJson()),
        ],
        'history': [
          ...snapshot.history.map((item) => item.toJson()),
          event.toJson(),
        ],
      }),
    );
  }
}
