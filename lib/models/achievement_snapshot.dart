import 'achievement.dart';
import 'progress_history_entry.dart';

// Достижения и история читаются и сохраняются одной согласованной записью.
class AchievementSnapshot {
  AchievementSnapshot({
    required List<Achievement> achievements,
    required List<ProgressHistoryEntry> history,
  }) : achievements = List.unmodifiable(achievements),
       history = List.unmodifiable(history);

  final List<Achievement> achievements;
  final List<ProgressHistoryEntry> history;
}
