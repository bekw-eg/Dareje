import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/progress_analytics.dart';
import 'package:student_achievements/models/progress_history_entry.dart';
import 'package:student_achievements/models/student_indicator.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/services/achievement_scoring_service.dart';
import 'package:student_achievements/services/analytics_data_source.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/services/progress_analytics_service.dart';

import 'achievements_test.dart' show AchievementPreferences;
import 'ranking_screen_test.dart' show TestRankingSource;
import 'student_ranking_test.dart' show rankingUser;

Achievement newAchievement(String category, {String? id, DateTime? date}) =>
    Achievement(
      id: id,
      title: category,
      description: 'Сипаттама',
      category: category,
      date: date ?? DateTime(2020, 1, 1),
    );

void main() {
  final now = DateTime.utc(2026, 10, 12, 12);
  final base = StudentProfile.initial(rankingUser('ali'));
  final scoring = AchievementScoringService();
  final analytics = ProgressAnalyticsService();
  late AchievementPreferences preferences;
  late LocalAchievementService service;

  setUp(() {
    preferences = AchievementPreferences();
    service = LocalAchievementService(
      login: 'ali',
      preferences: preferences,
      clock: () => now,
    );
  });

  test(
    'Legacy read stays read-only; migration records only the new change',
    () async {
      final old = newAchievement('Academic').toJson()..remove('id');
      preferences.values['dareje.achievements.v1.ali'] = jsonEncode([old]);
      final before = Map<String, String>.from(preferences.values);
      var snapshot = await service.loadSnapshot();
      expect(snapshot.history, isEmpty);
      expect(snapshot.achievements.single.id, isNull);
      expect(preferences.values, before);
      final added = newAchievement('Programming');
      await service.add(added);
      snapshot = await service.loadSnapshot();
      expect(snapshot.achievements.length, 2);
      final event = snapshot.history.single;
      expect(event.timestamp, now);
      expect(event.achievementId, added.id);
      expect(event.previousTotalScore, 50);
      expect(event.newTotalScore, 53);
      expect(event.indicatorChanges, {
        StudentIndicatorType.academic: 0,
        StudentIndicatorType.programming: 10,
        StudentIndicatorType.projects: 4,
        StudentIndicatorType.teamwork: 0,
        StudentIndicatorType.sport: 0,
        StudentIndicatorType.volunteering: 0,
      });
      final summary = analytics.summarize(
        data: ProgressAnalyticsData(
          profile: scoring.calculate(
            baseProfile: base,
            achievements: snapshot.achievements,
          ),
          achievements: snapshot.achievements,
          history: snapshot.history,
        ),
        period: AnalyticsPeriod.all,
        now: now,
      );
      expect(summary.timeline.first.historyEntry, event);
      expect(summary.timeline.last.historyEntry, isNull);
      expect(
        preferences.values['dareje.achievements.v1.ali'],
        jsonEncode([old]),
      );
    },
  );

  test(
    'Restart, retries and concurrent instances cannot duplicate events or scores',
    () async {
      final achievement = newAchievement('Programming');
      final restarted = LocalAchievementService(
        login: ' ALI ',
        preferences: preferences,
        clock: () => now,
      );
      await Future.wait([
        service.add(achievement),
        restarted.add(achievement),
        service.add(achievement),
      ]);
      await restarted.add(Achievement.fromJson(achievement.toJson()));
      var snapshot = await restarted.loadSnapshot();
      expect(snapshot.achievements.length, 1);
      expect(snapshot.history.length, 1);
      for (var i = 0; i < 3; i++) {
        expect(
          scoring
              .calculate(
                baseProfile: base,
                achievements: await restarted.load(),
              )
              .totalScore,
          51,
        );
      }
      final other = newAchievement('Projects');
      await Future.wait([
        service.add(other),
        restarted.add(newAchievement('Sport')),
      ]);
      snapshot = await restarted.loadSnapshot();
      expect(snapshot.achievements.length, 3);
      expect(snapshot.history.length, 3);
      expect(
        snapshot.history[1].previousTotalScore,
        snapshot.history[0].newTotalScore,
      );
      expect(
        snapshot.history[2].previousTotalScore,
        snapshot.history[1].newTotalScore,
      );
      expect(
        snapshot.history.last.newTotalScore,
        scoring
            .calculate(baseProfile: base, achievements: snapshot.achievements)
            .totalScore,
      );
      expect(
        (await LocalAchievementService(
          login: 'other',
          preferences: preferences,
        ).loadSnapshot()).history,
        isEmpty,
      );
    },
  );

  test(
    'Failed save is atomic, retry works, and corrupt history is not overwritten',
    () async {
      final achievement = newAchievement('Academic');
      preferences.failWrites = true;
      await expectLater(service.add(achievement), throwsStateError);
      expect(preferences.values, isEmpty);
      preferences.failWrites = false;
      await service.add(achievement);
      expect((await service.loadSnapshot()).history.length, 1);
      final json =
          jsonDecode(preferences.values['dareje.achievements.v2.ali']!)
              as Map<String, dynamic>;
      json['history'] = 'corrupt';
      preferences.values['dareje.achievements.v2.ali'] = jsonEncode(json);
      final before = Map<String, String>.from(preferences.values);
      await expectLater(
        service.add(newAchievement('Sport')),
        throwsA(isA<TypeError>()),
      );
      expect(preferences.values, before);
    },
  );

  test('Actual changes respect saturation and total score rounding', () async {
    for (var i = 0; i < 4; i++) {
      await service.add(newAchievement('Programming'));
    }
    var snapshot = await service.loadSnapshot();
    expect(
      snapshot.history.last.indicatorChanges[StudentIndicatorType.programming],
      2,
    );
    expect(
      snapshot.history.last.indicatorChanges[StudentIndicatorType.projects],
      4,
    );
    expect(
      snapshot.history.last.newTotalScore,
      scoring
          .calculate(baseProfile: base, achievements: snapshot.achievements)
          .totalScore,
    );
    for (var i = 0; i < 9; i++) {
      await service.add(newAchievement('Programming'));
    }
    snapshot = await service.loadSnapshot();
    expect(
      snapshot.history.last.indicatorChanges.values.every(
        (value) => value == 0,
      ),
      isTrue,
    );
    expect(snapshot.history.last.totalScoreChange, 0);
    expect(
      snapshot.history.length,
      13,
    ); // Сохранение при 100 тоже является реальным наблюдением.
  });

  test(
    '7/30/90 days and all time include boundaries and exclude future events',
    () {
      ProgressHistoryEntry event(String id, DateTime time) =>
          ProgressHistoryEntry(
            id: id,
            timestamp: time,
            previousTotalScore: 48,
            newTotalScore: 50,
            indicatorChanges: {StudentIndicatorType.academic: 10},
          );
      final entries = [
        event('old', now.subtract(const Duration(days: 120))),
        event('90', now.subtract(const Duration(days: 90))),
        event('30', now.subtract(const Duration(days: 30))),
        event('7', now.subtract(const Duration(days: 7))),
        event('now', now),
        event('future', now.add(const Duration(seconds: 1))),
      ];
      final data = ProgressAnalyticsData(
        profile: base,
        achievements: [],
        history: [...entries, entries[4]],
      );
      for (final pair in [
        (AnalyticsPeriod.week, 2),
        (AnalyticsPeriod.month, 3),
        (AnalyticsPeriod.quarter, 4),
        (AnalyticsPeriod.all, 5),
      ]) {
        final result = analytics.summarize(
          data: data,
          period: pair.$1,
          now: now,
        );
        expect(result.events.length, pair.$2);
        expect(result.recordedScoreChange, pair.$2 * 2);
        expect(result.categories.first.recordedChange, pair.$2 * 10);
      }
      final emptyPeriod = analytics.summarize(
        data: ProgressAnalyticsData(
          profile: base,
          achievements: [],
          history: [entries.first],
        ),
        period: AnalyticsPeriod.week,
        now: now,
      );
      expect(emptyPeriod.events, isEmpty);
      expect(emptyPeriod.recordedScoreChange, 0);
    },
  );

  test('Counts, strongest, lowest current value, ties and timeline order', () {
    final achievements = [
      newAchievement('Academic', date: DateTime(2026, 10, 10)),
      newAchievement('Other', date: DateTime(2026, 10, 11)),
      newAchievement('Sport', date: DateTime(2026, 10, 9)),
    ];
    final profile = scoring.calculate(
      baseProfile: base,
      achievements: achievements,
    );
    final summary = analytics.summarize(
      data: ProgressAnalyticsData(
        profile: profile,
        achievements: achievements,
        history: [],
      ),
      period: AnalyticsPeriod.all,
      now: now,
    );
    expect(summary.strongest.single.type, StudentIndicatorType.academic);
    expect(
      summary.growthOpportunity.single.type,
      StudentIndicatorType.volunteering,
    );
    expect(summary.categories.map((c) => c.achievementCount), [
      1,
      0,
      0,
      0,
      1,
      0,
    ]);
    expect(summary.timeline.map((e) => e.achievement.category), [
      'Other',
      'Academic',
      'Sport',
    ]);
    expect(summary.timeline.every((e) => e.historyEntry == null), isTrue);
    expect(summary.recordedScoreChange, isNull);
    final tied = StudentProfile(
      user: base.user,
      indicators: [
        for (final i in base.indicators)
          StudentIndicator(type: i.type, name: i.name, value: 50),
      ],
    );
    final ties = analytics.summarize(
      data: ProgressAnalyticsData(profile: tied, achievements: [], history: []),
      period: AnalyticsPeriod.all,
      now: now,
    );
    expect(ties.strongest.length, 6);
    expect(ties.growthOpportunity.length, 6);
    final empty = analytics.summarize(
      data: ProgressAnalyticsData(
        profile: StudentProfile(user: base.user, indicators: []),
        achievements: [],
        history: [],
      ),
      period: AnalyticsPeriod.week,
      now: now,
    );
    expect(empty.categories, isEmpty);
    expect(empty.strongest, isEmpty);
    expect(empty.events, isEmpty);
  });

  test(
    'Data source uses real ranking and profile; failures never invent a position',
    () async {
      final ranking = TestRankingSource()
        ..profiles = [base, StudentProfile.initial(rankingUser('other'))];
      final source = LocalAnalyticsDataSource(
        baseProfile: base,
        achievementService: service,
        rankingDataSource: ranking,
      );
      expect((await source.load()).rankingPosition, 1);
      await service.add(newAchievement('Sport'));
      final data = await source.load();
      expect(data.profile.totalScore, 50);
      expect(data.profile.achievementCount, 1);
      expect(data.history.single.newTotalScore, data.profile.totalScore);
      expect(data.rankingPosition, 1);
      ranking.failReads = true;
      final failed = await source.load();
      expect(failed.rankingPosition, isNull);
      expect(failed.rankingUnavailable, isTrue);
      expect(failed.profile.totalScore, 50);
      preferences.failReads = true;
      await expectLater(source.load(), throwsStateError);
    },
  );
}
