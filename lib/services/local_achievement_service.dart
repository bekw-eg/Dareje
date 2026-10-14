import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/achievement_snapshot.dart';
import '../models/progress_history_entry.dart';
import 'progress_history_service.dart';

class AchievementException implements Exception {
  const AchievementException(this.message);
  final String message;
}

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
        achievements: await _readAchievements(
          json['achievements'] as List<dynamic>,
        ),
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
          : await _readAchievements(jsonDecode(legacy) as List<dynamic>),
      history: [],
    );
  }

  Future<List<Achievement>> _readAchievements(List<dynamic> json) async {
    final items = <Achievement>[];
    final ids = <String>{};
    for (var index = 0; index < json.length; index++) {
      var item = Achievement.fromJson(json[index] as Map<String, dynamic>);
      if (item.id == null) {
        // Индекс различает одинаковые старые записи. Чтение ничего не записывает;
        // первая успешная правка закрепляет эти ID в общем документе v2.
        final hash = await Sha256().hash(
          utf8.encode('$index:${jsonEncode(item.toJson())}'),
        );
        item = item.copyWith(id: 'legacy-${base64UrlEncode(hash.bytes)}');
      }
      if (item.id!.isEmpty || !ids.add(item.id!)) {
        throw const FormatException('Duplicate or empty achievement ID');
      }
      items.add(item);
    }
    return items;
  }

  Future<void> add(Achievement achievement) =>
      _enqueue(() => _add(achievement));

  Future<void> update(Achievement original, Achievement updated) =>
      _enqueue(() => _update(original, updated));

  Future<void> delete(Achievement achievement) =>
      _enqueue(() => _delete(achievement));

  Future<void> _enqueue(Future<void> Function() write) async {
    final previous = _writes[_storageKey] ?? Future<void>.value();
    final operation = previous.then((_) => write());
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
    if (snapshot.achievements.any((item) => item.id == achievement.id) ||
        snapshot.history.any(
          (event) => event.achievementId == achievement.id,
        )) {
      return;
    }
    final event = _historyService.recordAddition(
      before: snapshot.achievements,
      achievement: achievement,
      timestamp: _clock(),
    );
    await _save(
      [achievement, ...snapshot.achievements],
      [...snapshot.history, event],
    );
  }

  Future<void> _update(Achievement original, Achievement updated) async {
    if (original.id == null || updated.id != original.id) {
      throw ArgumentError('An edit must preserve the achievement ID');
    }
    final snapshot = await loadSnapshot();
    final index = snapshot.achievements.indexWhere(
      (item) => item.id == original.id,
    );
    if (index < 0) throw _staleAchievement;
    final current = snapshot.achievements[index];
    // Без изменений и при повторе уже сохранённой правки не создаём событие.
    if (current.hasSameContent(updated)) return;
    if (!current.hasSameContent(original)) throw _staleAchievement;
    final items = [...snapshot.achievements];
    items[index] = updated;
    final event = _historyService.recordChange(
      before: snapshot.achievements,
      after: items,
      achievementId: original.id!,
      operation: AchievementChange.update,
      timestamp: _clock(),
    );
    await _save(items, [...snapshot.history, event]);
  }

  Future<void> _delete(Achievement achievement) async {
    if (achievement.id == null) throw ArgumentError('Deletion requires an ID');
    final snapshot = await loadSnapshot();
    final index = snapshot.achievements.indexWhere(
      (item) => item.id == achievement.id,
    );
    if (index < 0) {
      if (snapshot.history.any(
        (event) =>
            event.achievementId == achievement.id &&
            event.operation == AchievementChange.deletion,
      ))
        return;
      throw _staleAchievement;
    }
    if (!snapshot.achievements[index].hasSameContent(achievement)) {
      throw _staleAchievement;
    }
    final items = [...snapshot.achievements]..removeAt(index);
    final event = _historyService.recordChange(
      before: snapshot.achievements,
      after: items,
      achievementId: achievement.id!,
      operation: AchievementChange.deletion,
      timestamp: _clock(),
    );
    await _save(items, [...snapshot.history, event]);
  }

  static const _staleAchievement = AchievementException(
    'Жетістік өзгертілген немесе өшірілген. Тізімді жаңартып, қайта көріңіз',
  );

  // Изменение и реальное влияние сохраняются вместе. Историю не переписываем;
  // ошибка записи сохраняет прежнее состояние. Старый документ v1 не удаляем.
  Future<void> _save(
    List<Achievement> achievements,
    List<ProgressHistoryEntry> history,
  ) async {
    await _preferences.setString(
      _storageKey,
      jsonEncode({
        'version': 2,
        'achievements': [...achievements.map((item) => item.toJson())],
        'history': [...history.map((item) => item.toJson())],
      }),
    );
  }
}
