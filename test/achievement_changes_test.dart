import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/progress_analytics.dart';
import 'package:student_achievements/models/progress_history_entry.dart';
import 'package:student_achievements/models/student_indicator.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/services/achievement_scoring_service.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/services/progress_analytics_service.dart';
import 'package:student_achievements/services/ranking_data_source.dart';
import 'package:student_achievements/services/student_ranking_service.dart';
import 'package:student_achievements/services/local_auth_service.dart';

import 'achievements_test.dart' show AchievementPreferences;
import 'auth_test.dart' show MemoryPreferences;
import 'student_ranking_test.dart' show rankingUser;

Achievement item(String title, {String category = 'Programming'}) =>
    Achievement(
      title: title,
      description: 'Сипаттама',
      category: category,
      date: DateTime(2026, 10, 10),
    );

void main() {
  final now = DateTime.utc(2026, 10, 14, 12);
  final base = StudentProfile.initial(rankingUser('ali'));
  final scoring = AchievementScoringService();
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
    'Edit preserves ID, list order and old events; delete returns to base',
    () async {
      final original = item('Хакатон');
      final another = item('Олимпиада', category: 'Academic');
      await service.add(original);
      await service.add(another);
      final oldEvents = (await service.loadSnapshot()).history
          .map((e) => e.toJson())
          .toList();
      final updated = original.copyWith(
        title: 'Жоба',
        description: 'Жаңартылған сипаттама',
        category: 'Projects',
        date: DateTime(2026, 10, 12),
      );
      await service.update(original, updated);
      var snapshot = await service.loadSnapshot();
      expect(snapshot.achievements.map((a) => a.id), [another.id, original.id]);
      expect(snapshot.achievements.last.toJson(), updated.toJson());
      expect(snapshot.history.take(2).map((e) => e.toJson()), oldEvents);
      final edit = snapshot.history.last;
      expect(edit.operation, AchievementChange.update);
      expect(edit.timestamp, now);
      expect(edit.indicatorChanges, {
        StudentIndicatorType.academic: 0,
        StudentIndicatorType.programming: -6,
        StudentIndicatorType.projects: 6,
        StudentIndicatorType.teamwork: 3,
        StudentIndicatorType.sport: 0,
        StudentIndicatorType.volunteering: 0,
      });
      final restarted = LocalAchievementService(
        login: 'ALI',
        preferences: preferences,
        clock: () => now,
      );
      expect((await restarted.load()).last.toJson(), updated.toJson());
      await restarted.delete(updated);
      await restarted.delete(another);
      snapshot = await restarted.loadSnapshot();
      expect(snapshot.achievements, isEmpty);
      expect(snapshot.history.length, 5);
      expect(snapshot.history.last.operation, AchievementChange.deletion);
      expect(snapshot.history.last.newTotalScore, 48);
      expect(
        scoring
            .calculate(baseProfile: base, achievements: snapshot.achievements)
            .totalScore,
        48,
      );
      for (var i = 1; i < snapshot.history.length; i++) {
        expect(
          snapshot.history[i].previousTotalScore,
          snapshot.history[i - 1].newTotalScore,
        );
      }
      final summary = ProgressAnalyticsService().summarize(
        data: ProgressAnalyticsData(
          profile: base,
          achievements: [],
          history: snapshot.history,
        ),
        period: AnalyticsPeriod.all,
        now: now,
      );
      expect(
        summary.events.map((e) => e.id),
        snapshot.history.map((e) => e.id),
      );
      expect(summary.recordedScoreChange, 0);
      expect(summary.timeline, isEmpty);
      expect(summary.categories.every((c) => c.recordedChange == 0), isTrue);
    },
  );

  test(
    'Retries and unchanged edits create no duplicates or resurrection',
    () async {
      final original = item('Хакатон');
      await service.add(original);
      final before = Map<String, String>.from(preferences.values);
      await service.update(original, original);
      expect(preferences.values, before);
      final updated = original.copyWith(title: 'Өңделген');
      await service.update(original, updated);
      await service.update(original, updated);
      var snapshot = await service.loadSnapshot();
      expect(snapshot.history.length, 2);
      expect(
        snapshot.history.last.indicatorChanges.values.every(
          (value) => value == 0,
        ),
        true,
      );
      expect(snapshot.history.last.totalScoreChange, 0);
      final summary = ProgressAnalyticsService().summarize(
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
      expect(
        summary.timeline.single.historyEntry?.operation,
        AchievementChange.update,
      );
      await service.delete(updated);
      final deleted = Map<String, String>.from(preferences.values);
      await service.delete(updated);
      await service.add(original);
      expect(preferences.values, deleted);
      snapshot = await service.loadSnapshot();
      expect(snapshot.achievements, isEmpty);
      expect(snapshot.history.length, 3);
      await expectLater(
        service.update(original, updated),
        throwsA(isA<AchievementException>()),
      );
    },
  );

  test(
    'Failed writes, read errors and corrupt data preserve the document',
    () async {
      final original = item('Хакатон');
      await service.add(original);
      final before = Map<String, String>.from(preferences.values);
      final updated = original.copyWith(category: 'Sport');
      preferences.failWrites = true;
      await expectLater(service.update(original, updated), throwsStateError);
      await expectLater(service.delete(original), throwsStateError);
      expect(preferences.values, before);
      preferences.failWrites = false;
      preferences.failReads = true;
      await expectLater(service.update(original, updated), throwsStateError);
      await expectLater(service.delete(original), throwsStateError);
      expect(preferences.values, before);
      preferences.failReads = false;
      await service.update(original, updated);
      expect((await service.load()).single.category, 'Sport');
      final stored =
          jsonDecode(preferences.values['dareje.achievements.v2.ali']!)
              as Map<String, dynamic>;
      stored['history'] = 'broken';
      preferences.values['dareje.achievements.v2.ali'] = jsonEncode(stored);
      final corrupt = Map<String, String>.from(preferences.values);
      await expectLater(service.delete(updated), throwsA(isA<TypeError>()));
      await expectLater(
        service.update(updated, original),
        throwsA(isA<TypeError>()),
      );
      expect(preferences.values, corrupt);
    },
  );

  test(
    'Legacy duplicate rows get stable separate IDs without fabricated history',
    () async {
      final legacy = item('Бұрынғы').toJson()..remove('id');
      preferences.values['dareje.achievements.v1.ali'] = jsonEncode([
        legacy,
        legacy,
      ]);
      final before = Map<String, String>.from(preferences.values);
      final loaded = await service.load();
      expect(loaded[0].id, isNot(loaded[1].id));
      expect((await service.load()).map((a) => a.id), loaded.map((a) => a.id));
      expect(preferences.values, before);
      expect((await service.loadSnapshot()).history, isEmpty);
      preferences.failWrites = true;
      await expectLater(service.delete(loaded[1]), throwsStateError);
      expect(preferences.values, before);
      preferences.failWrites = false;
      await service.update(loaded[1], loaded[1].copyWith(title: 'Екінші'));
      var snapshot = await service.loadSnapshot();
      expect(snapshot.achievements.first.id, loaded[0].id);
      expect(snapshot.achievements.last.id, loaded[1].id);
      expect(snapshot.history.single.operation, AchievementChange.update);
      expect(
        snapshot.history.single.previousTotalScore,
        snapshot.history.single.newTotalScore,
      );
      await service.delete(loaded[0]);
      await service.delete(loaded[0]);
      snapshot = await service.loadSnapshot();
      expect(snapshot.achievements.single.title, 'Екінші');
      expect(snapshot.achievements.single.id, loaded[1].id);
      expect(snapshot.history.length, 2);
      expect(
        preferences.values['dareje.achievements.v1.ali'],
        before['dareje.achievements.v1.ali'],
      );
      final restarted = LocalAchievementService(
        login: 'ali',
        preferences: preferences,
      );
      expect((await restarted.load()).single.id, loaded[1].id);
    },
  );

  test(
    'V2 rows without IDs stay stable when a new achievement shifts list positions',
    () async {
      final legacy = item('Бұрынғы').toJson()..remove('id');
      preferences.values['dareje.achievements.v2.ali'] = jsonEncode({
        'version': 2,
        'achievements': [legacy, legacy],
        'history': [],
      });
      final old = await service.load();
      await service.add(item('Жаңа'));
      await service.delete(old[1]);
      final snapshot = await service.loadSnapshot();
      expect(snapshot.achievements.map((a) => a.title), ['Жаңа', 'Бұрынғы']);
      expect(snapshot.achievements.last.id, old[0].id);
      expect(snapshot.history.map((e) => e.operation), [
        AchievementChange.addition,
        AchievementChange.deletion,
      ]);
    },
  );

  test(
    'Deleting at the cap records the actual change rather than subtracting a bonus',
    () async {
      final items = List.generate(14, (index) => item('Хакатон $index'));
      for (final achievement in items) {
        await service.add(achievement);
      }
      await service.delete(items.last);
      var snapshot = await service.loadSnapshot();
      expect(
        snapshot.history.last.indicatorChanges.values.every(
          (value) => value == 0,
        ),
        true,
      );
      expect(snapshot.history.last.totalScoreChange, 0);
      for (final achievement in items.take(10)) {
        await service.delete(achievement);
      }
      snapshot = await service.loadSnapshot();
      expect(
        snapshot.history.last.indicatorChanges[StudentIndicatorType
            .programming],
        -2,
      );
      expect(
        snapshot.history.last.indicatorChanges[StudentIndicatorType.projects],
        -4,
      );
      expect(
        snapshot.history.last.newTotalScore,
        scoring
            .calculate(baseProfile: base, achievements: snapshot.achievements)
            .totalScore,
      );
    },
  );

  test(
    'The account queue preserves independent writes and rejects stale edit/delete',
    () async {
      final original = item('Хакатон');
      await service.add(original);
      final otherService = LocalAchievementService(
        login: ' ALI ',
        preferences: preferences,
        clock: () => now,
      );
      final updated = original.copyWith(category: 'Projects');
      await Future.wait([
        service.update(original, updated),
        otherService.add(item('Спорт', category: 'Sport')),
      ]);
      final before = Map<String, String>.from(preferences.values);
      await expectLater(
        otherService.update(original, original.copyWith(title: 'Застарған')),
        throwsA(isA<AchievementException>()),
      );
      await expectLater(
        otherService.delete(original),
        throwsA(isA<AchievementException>()),
      );
      expect(preferences.values, before);
      await Future.wait([
        service.delete(updated),
        otherService.delete(updated),
      ]);
      final snapshot = await service.loadSnapshot();
      expect(snapshot.achievements.single.category, 'Sport');
      expect(snapshot.history.length, 4);
      expect(snapshot.history.map((e) => e.id).toSet().length, 4);
    },
  );

  test('ID tampering and duplicate stored IDs cannot change data', () async {
    final original = item('Хакатон');
    await service.add(original);
    final before = Map<String, String>.from(preferences.values);
    await expectLater(
      service.update(original, original.copyWith(id: 'different')),
      throwsArgumentError,
    );
    await expectLater(
      service.delete(item('Missing')),
      throwsA(isA<AchievementException>()),
    );
    expect(preferences.values, before);
    final stored =
        jsonDecode(preferences.values['dareje.achievements.v2.ali']!)
            as Map<String, dynamic>;
    stored['achievements'] = [original.toJson(), original.toJson()];
    preferences.values['dareje.achievements.v2.ali'] = jsonEncode(stored);
    final corrupt = Map<String, String>.from(preferences.values);
    await expectLater(service.delete(original), throwsFormatException);
    expect(preferences.values, corrupt);
  });

  test(
    'Old event JSON defaults to addition; new operation survives restart',
    () async {
      final original = item('Хакатон');
      await service.add(original);
      final oldEvent = (await service.loadSnapshot()).history.single.toJson()
        ..remove('operation');
      expect(
        ProgressHistoryEntry.fromJson(oldEvent).operation,
        AchievementChange.addition,
      );
      await service.delete(original);
      final event = (await service.loadSnapshot()).history.last;
      expect(
        ProgressHistoryEntry.fromJson(event.toJson()).operation,
        AchievementChange.deletion,
      );
    },
  );

  test(
    'Local ranking refreshes after edits and deletions without touching other accounts',
    () async {
      final auth = LocalAuthService(
        preferences: MemoryPreferences(
          saved: jsonEncode({
            'users': [
              rankingUser('ali').toJson(),
              rankingUser('other').toJson(),
            ],
            'activeLogin': 'ali',
          }),
        ),
      );
      await auth.load();
      addTearDown(auth.dispose);
      final otherService = LocalAchievementService(
        login: 'other',
        preferences: preferences,
      );
      final original = item('Хакатон');
      await service.add(original);
      await otherService.add(item('Олимпиада', category: 'Academic'));
      final otherSaved = preferences.values['dareje.achievements.v2.other'];
      final source = LocalRankingDataSource(
        authService: auth,
        achievementServiceFor: (login) =>
            login == 'ali' ? service : otherService,
      );
      final ranking = StudentRankingService();
      expect(
        ranking.rank(await source.loadProfiles()).first.profile.user.login,
        'ali',
      );
      final updated = original.copyWith(category: 'Other');
      await service.update(original, updated);
      var entries = ranking.rank(await source.loadProfiles());
      expect(entries.first.profile.user.login, 'other');
      expect(entries.last.profile.totalScore, 49);
      await service.delete(updated);
      entries = ranking.rank(await source.loadProfiles());
      expect(entries.last.profile.totalScore, 48);
      expect(entries.last.profile.achievementCount, 0);
      expect(preferences.values['dareje.achievements.v2.other'], otherSaved);
    },
  );
}
