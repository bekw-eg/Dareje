import '../models/progress_analytics.dart';
import '../models/progress_history_entry.dart';
import '../models/student_indicator.dart';

class ProgressAnalyticsService {
  static const _achievementCategory = {
    StudentIndicatorType.academic: 'Academic',
    StudentIndicatorType.programming: 'Programming',
    StudentIndicatorType.projects: 'Projects',
    StudentIndicatorType.sport: 'Sport',
    StudentIndicatorType.volunteering: 'Volunteering',
  };

  ProgressAnalyticsSummary summarize({
    required ProgressAnalyticsData data,
    required AnalyticsPeriod period,
    required DateTime now,
  }) {
    final end = now.toUtc();
    final start = period.days == null
        ? null
        : end.subtract(Duration(days: period.days!));
    final history = <ProgressHistoryEntry>[];
    final ids = <String>{};
    // Дополнительная защита чтения: один event ID учитывается только один раз.
    for (final event in data.history) {
      if (ids.add(event.id) && !event.timestamp.isAfter(end))
        history.add(event);
    }
    history.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final events = history
        .where((event) => start == null || !event.timestamp.isBefore(start))
        .toList();
    final indicators = data.profile.indicators;
    final strongest = <StudentIndicator>[];
    final weakest = <StudentIndicator>[];
    for (final indicator in indicators) {
      if (strongest.isEmpty || indicator.value > strongest.first.value) {
        strongest
          ..clear()
          ..add(indicator);
      } else if (indicator.value == strongest.first.value) {
        strongest.add(indicator);
      }
      if (weakest.isEmpty || indicator.value < weakest.first.value) {
        weakest
          ..clear()
          ..add(indicator);
      } else if (indicator.value == weakest.first.value) {
        weakest.add(indicator);
      }
    }
    final eventsByAchievement = {
      for (final event in history)
        if (event.achievementId != null) event.achievementId!: event,
    };
    final timeline = [
      for (final achievement in data.achievements)
        AchievementTimelineEntry(
          achievement,
          eventsByAchievement[achievement.id],
        ),
    ];
    timeline.sort((a, b) {
      final byDate = b.achievement.date.compareTo(a.achievement.date);
      if (byDate != 0) return byDate;
      return (b.historyEntry?.timestamp ?? b.achievement.date).compareTo(
        a.historyEntry?.timestamp ?? a.achievement.date,
      );
    });
    return ProgressAnalyticsSummary(
      data: data,
      events: List.unmodifiable(events),
      recordedScoreChange: history.isEmpty
          ? null
          : events.fold<int>(0, (sum, e) => sum + e.totalScoreChange),
      categories: List.unmodifiable([
        for (final indicator in indicators)
          CategoryAnalytics(
            indicator: indicator,
            achievementCount: data.achievements
                .where(
                  (a) => a.category == _achievementCategory[indicator.type],
                )
                .length,
            recordedChange: history.isEmpty
                ? null
                : events.fold<int>(
                    0,
                    (sum, e) => sum + (e.indicatorChanges[indicator.type] ?? 0),
                  ),
          ),
      ]),
      timeline: List.unmodifiable(timeline),
      strongest: List.unmodifiable(strongest),
      growthOpportunity: List.unmodifiable(weakest),
    );
  }
}
