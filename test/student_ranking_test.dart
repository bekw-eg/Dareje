import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/local_user.dart';
import 'package:student_achievements/models/student_indicator.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/services/local_auth_service.dart';
import 'package:student_achievements/services/ranking_data_source.dart';
import 'package:student_achievements/services/student_ranking_service.dart';

import 'achievements_test.dart' show AchievementPreferences;

LocalUser rankingUser(String login) => LocalUser(
  login: login,
  firstName: login == 'ali' ? 'Әли' : 'Айдана',
  lastName: 'Ермек',
  email: '$login@example.kz',
  passwordHash: '',
  salt: '',
);

StudentProfile rankingProfile(String login, int score) => StudentProfile(
  user: rankingUser(login),
  indicators: [
    StudentIndicator(
      type: StudentIndicatorType.academic,
      name: 'Оқу',
      value: score,
    ),
  ],
);

void main() {
  final ranking = StudentRankingService();

  test('Descending scores, competition places and stable login tie order', () {
    final profiles = [
      rankingProfile('d', 60),
      rankingProfile('b', 90),
      rankingProfile('a', 90),
      rankingProfile('e', 0),
      rankingProfile('c', 60),
    ];
    final entries = ranking.rank(profiles);
    expect(entries.map((entry) => entry.profile.user.login), [
      'a',
      'b',
      'c',
      'd',
      'e',
    ]);
    expect(entries.map((entry) => entry.profile.totalScore), [
      90,
      90,
      60,
      60,
      0,
    ]);
    expect(entries.map((entry) => entry.position), [1, 1, 3, 3, 5]);
    expect(profiles.map((profile) => profile.user.login), [
      'd',
      'b',
      'a',
      'e',
      'c',
    ]);
    final reloaded = ranking.rank(profiles.reversed.toList());
    expect(reloaded.map((entry) => entry.profile.user.login), [
      'a',
      'b',
      'c',
      'd',
      'e',
    ]);
    expect(entries.first.profile, same(profiles[2]));
    expect(() => entries.clear(), throwsUnsupportedError);
  });

  test('Empty, single student and all tied students', () {
    expect(ranking.rank([]), isEmpty);
    expect(ranking.rank([rankingProfile('ali', 48)]).single.position, 1);
    expect(
      ranking
          .rank([
            for (final login in ['c', 'a', 'b']) rankingProfile(login, 48),
          ])
          .map((entry) => entry.position),
      [1, 1, 1],
    );
  });

  group('Real local source', () {
    late AchievementPreferences preferences;
    late LocalAuthService auth;
    late LocalRankingDataSource source;

    LocalAchievementService achievements(String login) =>
        LocalAchievementService(login: login, preferences: preferences);

    setUp(() async {
      preferences = AchievementPreferences();
      preferences.values[LocalAuthService.storageKey] = jsonEncode({
        'users': [rankingUser('ali').toJson(), rankingUser('aidana').toJson()],
        'activeLogin': 'ali',
      });
      auth = LocalAuthService(preferences: preferences);
      await auth.load();
      source = LocalRankingDataSource(
        authService: auth,
        achievementServiceFor: achievements,
      );
    });

    tearDown(() => auth.dispose());

    test(
      'Only registered accounts; source is read-only and updates after save',
      () async {
        final before = Map<String, String>.from(preferences.values);
        var entries = ranking.rank(await source.loadProfiles());
        expect(entries.map((entry) => entry.position), [1, 1]);
        expect(entries.map((entry) => entry.profile.totalScore), [48, 48]);
        expect(preferences.values, before);
        expect(() => auth.registeredUsers.clear(), throwsUnsupportedError);

        final achievement = Achievement(
          title: 'Хакатон',
          description: 'Бірінші орын',
          category: 'Programming',
          date: DateTime(2026, 10, 10),
        );
        await achievements('ali').add(achievement);
        await achievements('orphan').add(achievement);
        final saved = Map<String, String>.from(preferences.values);
        for (var attempt = 0; attempt < 3; attempt++) {
          entries = ranking.rank(await source.loadProfiles());
          expect(entries.map((entry) => entry.profile.user.login), [
            'ali',
            'aidana',
          ]);
          expect(entries.map((entry) => entry.position), [1, 2]);
          expect(entries.map((entry) => entry.profile.totalScore), [51, 48]);
          expect(entries.first.profile.achievementCount, 1);
          expect(entries.last.profile.achievementCount, 0);
        }
        expect(preferences.values, saved);
        expect(auth.currentUser?.login, 'ali');

        final restartedAuth = LocalAuthService(preferences: preferences);
        await restartedAuth.load();
        final restarted = LocalRankingDataSource(
          authService: restartedAuth,
          achievementServiceFor: achievements,
        );
        expect(
          (await restarted.loadProfiles()).map((profile) => profile.totalScore),
          [51, 48],
        );
        restartedAuth.dispose();
      },
    );

    test(
      'Empty registry remains empty; failure never hides a student',
      () async {
        final emptyAuth = LocalAuthService(
          preferences: AchievementPreferences(),
        );
        await emptyAuth.load();
        expect(
          await LocalRankingDataSource(
            authService: emptyAuth,
            achievementServiceFor: achievements,
          ).loadProfiles(),
          isEmpty,
        );
        emptyAuth.dispose();

        preferences.failReads = true;
        await expectLater(source.loadProfiles(), throwsStateError);
        preferences.failReads = false;
        preferences.values['dareje.achievements.v1.aidana'] = 'invalid json';
        await expectLater(source.loadProfiles(), throwsFormatException);
        preferences.values.remove('dareje.achievements.v1.aidana');
        expect((await source.loadProfiles()).length, 2);
      },
    );
  });
}
