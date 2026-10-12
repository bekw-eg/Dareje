import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/screens/main_screen.dart';
import 'package:student_achievements/screens/achievements_screen.dart';
import 'package:student_achievements/screens/add_achievement_screen.dart';
import 'package:student_achievements/services/local_auth_service.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/utils/app_theme.dart';
import 'package:student_achievements/widgets/achievement_tile.dart';
import 'package:student_achievements/widgets/app_widgets.dart';

import 'auth_test.dart' show MemoryPreferences;
import 'achievements_test.dart' show AchievementPreferences;
import 'ranking_screen_test.dart' show TestRankingSource;
import 'student_ranking_test.dart' show rankingUser, rankingProfile;

void main() {
  testWidgets(
    'All five tabs at 320px, double text, reduced motion and real data',
    (tester) async {
      WidgetController.hitTestWarningShouldBeFatal = true;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final user = rankingUser('ali');
      final auth = LocalAuthService(
        preferences: MemoryPreferences(
          saved: jsonEncode({
            'users': [user.toJson()],
            'activeLogin': user.login,
          }),
        ),
      );
      await auth.load();
      addTearDown(auth.dispose);
      final storage = AchievementPreferences();
      final achievements = LocalAchievementService(
        login: user.login,
        preferences: storage,
      );
      await achievements.add(
        Achievement(
          title: 'Нақты жоба',
          description: 'Толық сипаттама',
          category: 'Projects',
          date: DateTime(2026, 10, 12),
        ),
      );
      final ranking = TestRankingSource()
        ..profiles = [rankingProfile('other', 90), rankingProfile('ali', 51)];
      final saved = Map<String, String>.from(storage.values);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: MainScreen(
              authService: auth,
              achievementService: achievements,
              rankingDataSource: ranking,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppScoreRing>(find.byType(AppScoreRing)).score, 51);
      expect(find.text('#2'), findsOneWidget);
      for (final icon in [
        Icons.emoji_events_outlined,
        Icons.leaderboard_outlined,
        Icons.person_outline,
        Icons.insights_outlined,
      ]) {
        await tester.tap(find.byIcon(icon).last);
        await tester.pumpAndSettle();
        for (var i = 0; i < 7; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
      expect(storage.values, saved);
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Жетістік қосу'));
      await tester.tap(find.text('Жетістік қосу'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(3));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(storage.values, saved);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Expanded achievement shows full description and preserves stored category values',
    (tester) async {
      final item = Achievement(
        title: 'Хакатон',
        description: 'Толық сипаттама. ' * 40,
        category: 'Programming',
        date: DateTime(2026, 10, 12),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AchievementTile(achievement: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(item.description), findsNothing);
      await tester.tap(find.text('Хакатон'));
      await tester.pumpAndSettle();
      expect(find.text(item.description), findsOneWidget);
      expect(find.text('Бағдарламалау'), findsOneWidget);
      expect(item.toJson()['category'], 'Programming');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ring and skill data animate to new values without restarting the widget',
    (tester) async {
      final user = rankingUser('ali');
      Future<void> render(int score) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                AppScoreRing(score: score),
                SkillProgress(
                  indicator: StudentProfile.initial(user).indicators.first,
                ),
              ],
            ),
          ),
        ),
      );
      await render(48);
      await tester.pumpAndSettle();
      expect(find.text('48'), findsOneWidget);
      await render(60);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('48'), findsNothing);
      expect(find.text('60'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('60'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Category filters use saved data and never write to storage', (
    tester,
  ) async {
    final storage = AchievementPreferences();
    final service = LocalAchievementService(login: 'ali', preferences: storage);
    for (final category in ['Programming', 'Sport']) {
      await service.add(
        Achievement(
          title: 'Тексеру $category',
          description: 'Сипаттама',
          category: category,
          date: DateTime(2026, 10, 12),
        ),
      );
    }
    final saved = Map<String, String>.from(storage.values);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: AchievementsScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Бағдарламалау'));
    await tester.pumpAndSettle();
    expect(find.text('Тексеру Programming'), findsOneWidget);
    expect(find.text('Тексеру Sport'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Барлығы'));
    await tester.pumpAndSettle();
    expect(find.text('Тексеру Sport'), findsOneWidget);
    expect(storage.values, saved);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Achievement form scrolls above keyboard and shows validation at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = AchievementPreferences();
      final service = LocalAchievementService(
        login: 'ali',
        preferences: storage,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
              viewInsets: EdgeInsets.only(bottom: 280),
            ),
            child: AddAchievementScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Сақтау');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Жетістік атауын енгізіңіз'), findsOneWidget);
      expect(find.text('Санатты таңдаңыз'), findsOneWidget);
      expect(storage.values, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
