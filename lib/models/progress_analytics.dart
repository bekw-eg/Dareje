import 'achievement.dart';
import 'progress_history_entry.dart';
import 'student_indicator.dart';
import 'student_profile.dart';

enum AnalyticsPeriod {
  week(7, '7 күн'),
  month(30, '30 күн'),
  quarter(90, '90 күн'),
  all(null, 'Барлығы');

  const AnalyticsPeriod(this.days, this.label);
  final int? days;
  final String label;
}

class ProgressAnalyticsData {
  ProgressAnalyticsData({
    required this.profile,
    required List<Achievement> achievements,
    required List<ProgressHistoryEntry> history,
    this.rankingPosition,
    this.rankingUnavailable = false,
  }) : achievements = List.unmodifiable(achievements),
       history = List.unmodifiable(history);

  final StudentProfile profile;
  final List<Achievement> achievements;
  final List<ProgressHistoryEntry> history;
  final int? rankingPosition;
  final bool rankingUnavailable;
}

class CategoryAnalytics {
  const CategoryAnalytics({
    required this.indicator,
    required this.achievementCount,
    required this.recordedChange,
  });

  final StudentIndicator indicator;
  final int achievementCount;
  final int? recordedChange;
}

class AchievementTimelineEntry {
  const AchievementTimelineEntry(this.achievement, this.historyEntry);
  final Achievement achievement;
  final ProgressHistoryEntry? historyEntry;
}

class ProgressAnalyticsSummary {
  const ProgressAnalyticsSummary({
    required this.data,
    required this.events,
    required this.categories,
    required this.timeline,
    required this.recordedScoreChange,
    required this.strongest,
    required this.growthOpportunity,
  });

  final ProgressAnalyticsData data;
  final List<ProgressHistoryEntry> events;
  final List<CategoryAnalytics> categories;
  final List<AchievementTimelineEntry> timeline;
  final int? recordedScoreChange;
  // При равных значениях показываем все категории, не выбираем произвольно.
  final List<StudentIndicator> strongest;
  final List<StudentIndicator> growthOpportunity;
}
