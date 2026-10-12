import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/impact_scenario.dart';
import 'package:student_achievements/models/simulation_result.dart';
import 'package:student_achievements/models/student_indicator.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/services/achievement_scoring_service.dart';
import 'package:student_achievements/services/impact_simulation_data_source.dart';
import 'package:student_achievements/services/impact_simulation_service.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/services/ranking_data_source.dart';
import 'package:student_achievements/services/student_ranking_service.dart';

import 'achievements_test.dart' show AchievementPreferences;
import 'student_ranking_test.dart' show rankingUser;

class SimulationRankingSource implements RankingDataSource {
  List<StudentProfile> profiles = [];
  bool failReads = false;
  @override
  Future<List<StudentProfile>> loadProfiles() async {
    if (failReads) throw StateError('Ranking failed');
    return profiles;
  }
}

void main() {
  final engine = ImpactSimulationService();
  final scoring = AchievementScoringService();
  final base = StudentProfile.initial(rankingUser('ali'));
  final hackathon = ImpactScenario.examples.firstWhere(
    (s) => s.id == 'hackathon',
  );

  StudentProfile flat(String login, int score) => StudentProfile(
    user: rankingUser(login),
    indicators: [
      for (final item in base.indicators)
        StudentIndicator(type: item.type, name: item.name, value: score),
    ],
  );

  test(
    'Every scenario matches real Scoring and rounded total, without accumulation',
    () {
      final original = base.indicators.map((i) => i.value).toList();
      for (var attempt = 0; attempt < 3; attempt++) {
        for (final scenario in ImpactScenario.examples) {
          final result = engine.simulate(profile: base, scenario: scenario);
          final real = scoring.calculate(
            baseProfile: base,
            achievements: [
              Achievement(
                id: 'comparison-only',
                title: scenario.title,
                description: '',
                category: scenario.category,
                date: DateTime.utc(2026),
              ),
            ],
          );
          expect(
            result.afterMetrics.map((i) => i.value),
            real.indicators.map((i) => i.value),
          );
          expect(result.afterOverallScore, real.totalScore);
          expect(result.beforeOverallScore, 48);
          expect(result.beforeMetrics.map((i) => i.value), original);
          expect(result.afterProfile.achievementCount, base.achievementCount);
          for (final impact in result.impacts) {
            expect(
              result.metricDeltas[impact.before.type],
              impact.after.value - impact.before.value,
            );
            expect(impact.explanation, isNotEmpty);
          }
        }
      }
      expect(base.indicators.map((i) => i.value), original);
      expect(base.achievementCount, 0);
      expect(() => base.indicators.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Saturation explains actual 0 or partial delta; overall rounding is unchanged',
    () {
      final capped = flat('ali', 100);
      final noGrowth = engine.simulate(profile: capped, scenario: hackathon);
      expect(noGrowth.afterMetrics.every((i) => i.value == 100), isTrue);
      expect(noGrowth.metricDeltas.values.every((i) => i == 0), isTrue);
      expect(noGrowth.overallDelta, 0);
      final programming = noGrowth.impacts.firstWhere(
        (i) => i.before.type == StudentIndicatorType.programming,
      );
      expect(programming.potentialDelta, 10);
      expect(programming.limited, isTrue);
      expect(programming.explanation, contains('100'));

      final almost = engine.simulate(
        profile: flat('ali', 98),
        scenario: hackathon,
      );
      expect(almost.metricDeltas[StudentIndicatorType.programming], 2);
      expect(almost.metricDeltas[StudentIndicatorType.projects], 2);
      expect(almost.afterOverallScore, 99);
      final zero = engine.simulate(
        profile: flat('ali', 0),
        scenario: hackathon,
      );
      expect(zero.afterOverallScore, 2);
      expect(
        zero.afterMetrics.every((i) => i.value >= 0 && i.value <= 100),
        isTrue,
      );
    },
  );

  test('Other affects only teamwork and may not change rounded total', () {
    final other = ImpactScenario.examples.firstWhere(
      (s) => s.category == 'Other',
    );
    final result = engine.simulate(profile: base, scenario: other);
    expect(result.metricDeltas[StudentIndicatorType.teamwork], 2);
    expect(result.metricDeltas.values.where((v) => v != 0).length, 1);
    expect(result.overallDelta, 1);
    expect(result.afterOverallScore, 49);
    final rounded = engine.simulate(profile: flat('ali', 50), scenario: other);
    expect(rounded.overallDelta, 0);
    expect(rounded.metricDeltas[StudentIndicatorType.teamwork], 2);
    expect(() => result.impacts.clear(), throwsUnsupportedError);
    expect(() => result.metricDeltas.clear(), throwsUnsupportedError);
    expect(
      () => scoring.bonusesForCategory('Programming').clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'Ranking uses real peers, shared places and current snapshot; input order stays intact',
    () {
      final students = [
        flat('zed', 51),
        flat('ali', 0),
        flat('bea', 51),
        flat('dan', 48),
      ];
      final original = students.map((s) => s.totalScore).toList();
      final result = engine.simulate(
        profile: base,
        scenario: hackathon,
        rankingProfiles: students,
      );
      expect(result.currentRank, 3); // 51, 51, 48, 48
      expect(result.predictedRank, 1); // 51, 51, 51, 48
      expect(result.rankImprovement, 2);
      expect(result.rankingState, SimulationRankingState.available);
      expect(students.map((s) => s.user.login), ['zed', 'ali', 'bea', 'dan']);
      expect(students.map((s) => s.totalScore), original);
      final ranked = StudentRankingService().rank([
        for (final student in students)
          student.user.login == 'ali' ? result.afterProfile : student,
      ]);
      expect(ranked.map((e) => e.position), [1, 1, 1, 4]);
      expect(ranked.map((e) => e.profile.user.login), [
        'ali',
        'bea',
        'zed',
        'dan',
      ]);
      expect(base.totalScore, 48);
    },
  );

  test(
    'Missing, empty, failed and duplicate ranking never invent a position',
    () {
      for (final pair in <(List<StudentProfile>?, SimulationRankingState)>[
        (null, SimulationRankingState.unavailable),
        ([], SimulationRankingState.empty),
        ([flat('bea', 55)], SimulationRankingState.studentMissing),
        ([base, base], SimulationRankingState.unavailable),
      ]) {
        final result = engine.simulate(
          profile: base,
          scenario: hackathon,
          rankingProfiles: pair.$1,
        );
        expect(result.currentRank, isNull);
        expect(result.predictedRank, isNull);
        expect(result.rankImprovement, isNull);
        expect(result.rankingState, pair.$2);
        expect(result.afterOverallScore, 51);
        expect(result.rankingExplanation, isNotEmpty);
      }
      final solo = engine.simulate(
        profile: base,
        scenario: hackathon,
        rankingProfiles: [base],
      );
      expect(solo.currentRank, 1);
      expect(solo.predictedRank, 1);
      expect(solo.rankingState, SimulationRankingState.noPeers);
      expect(solo.rankingExplanation, contains('басқа студенттер жоқ'));
    },
  );

  test('Unknown categories are rejected', () {
    expect(
      () => ImpactScenario(
        id: 'bad',
        title: '',
        description: '',
        category: 'Teamwork',
      ),
      throwsArgumentError,
    );
    expect(
      ImpactScenario.examples.map((s) => s.category).toSet(),
      Achievement.categories.toSet(),
    );
  });

  group('Real storage and fresh data', () {
    late AchievementPreferences preferences;
    late LocalAchievementService achievements;
    late SimulationRankingSource ranking;
    late LocalImpactSimulationDataSource source;
    setUp(() {
      preferences = AchievementPreferences();
      achievements = LocalAchievementService(
        login: 'ali',
        preferences: preferences,
      );
      ranking = SimulationRankingSource()..profiles = [base, flat('bea', 50)];
      source = LocalImpactSimulationDataSource(
        baseProfile: base,
        achievementService: achievements,
        rankingDataSource: ranking,
      );
    });

    test(
      'Repeated simulations never write achievements, history or other accounts',
      () async {
        await achievements.add(
          Achievement(
            title: 'Жоба',
            description: '',
            category: 'Projects',
            date: DateTime.utc(2026),
          ),
        );
        await LocalAchievementService(
          login: 'bea',
          preferences: preferences,
        ).add(
          Achievement(
            title: 'Спорт',
            description: '',
            category: 'Sport',
            date: DateTime.utc(2026),
          ),
        );
        final saved = Map<String, String>.from(preferences.values);
        final snapshot = await achievements.loadSnapshot();
        preferences.failWrites =
            true; // Ни одна симуляция не должна вызывать запись.
        for (final scenario in ImpactScenario.examples) {
          final data = await source.load();
          engine.simulate(
            profile: data.profile,
            scenario: scenario,
            rankingProfiles: data.rankingProfiles,
          );
        }
        final after = await achievements.loadSnapshot();
        expect(preferences.values, saved);
        expect(
          after.achievements.map((a) => a.toJson()),
          snapshot.achievements.map((a) => a.toJson()),
        );
        expect(
          after.history.map((h) => h.toJson()),
          snapshot.history.map((h) => h.toJson()),
        );
        final next = await source.load();
        expect(next.profile.totalScore, 51);
        expect(() => next.rankingProfiles!.clear(), throwsUnsupportedError);
      },
    );

    test(
      'Legacy reads do not migrate or fabricate history; actual saves update next forecast',
      () async {
        preferences.values['dareje.achievements.v1.ali'] = jsonEncode([
          {
            'title': 'Ескі',
            'description': '',
            'category': 'Academic',
            'date': '2026-10-01T00:00:00.000',
          },
        ]);
        final original = Map<String, String>.from(preferences.values);
        final first = await source.load();
        engine.simulate(
          profile: first.profile,
          scenario: hackathon,
          rankingProfiles: first.rankingProfiles,
        );
        expect(first.profile.totalScore, 50);
        expect(preferences.values, original);
        expect((await achievements.loadSnapshot()).history, isEmpty);
        await achievements.add(
          Achievement(
            title: 'Нақты',
            description: '',
            category: 'Programming',
            date: DateTime.utc(2026),
          ),
        );
        final saved = Map<String, String>.from(preferences.values);
        final fresh = await source.load();
        final result = engine.simulate(
          profile: fresh.profile,
          scenario: hackathon,
          rankingProfiles: fresh.rankingProfiles,
        );
        expect(result.beforeOverallScore, 53);
        expect(result.afterOverallScore, 55);
        expect(preferences.values, saved);
        expect((await achievements.loadSnapshot()).history.length, 1);
      },
    );

    test(
      'Ranking failure preserves personal forecast; personal corruption is an error',
      () async {
        ranking.failReads = true;
        final data = await source.load();
        expect(data.profile.totalScore, 48);
        expect(data.rankingProfiles, isNull);
        expect(
          engine
              .simulate(profile: data.profile, scenario: hackathon)
              .afterOverallScore,
          51,
        );
        ranking.failReads = false;
        expect((await source.load()).rankingProfiles!.length, 2);
        preferences.values['dareje.achievements.v2.ali'] = 'broken';
        await expectLater(source.load(), throwsFormatException);
        expect(preferences.values['dareje.achievements.v2.ali'], 'broken');
      },
    );
  });
}
