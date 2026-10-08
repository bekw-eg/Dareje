import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/local_user.dart';
import 'package:student_achievements/models/student_indicator.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/screens/profile_screen.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/utils/app_theme.dart';

import 'achievements_test.dart' show AchievementPreferences;

void main() {
  const user = LocalUser(
    login: 'student',
    firstName: 'Әли',
    lastName: 'Ермек',
    email: 'ali@example.kz',
    passwordHash: '',
    salt: '',
  );

  test('Profile uses the account and averages replaceable indicators', () {
    final profile = StudentProfile.initial(user);
    expect(profile.name, 'Әли Ермек');
    expect(profile.email, user.email);
    expect(profile.indicators.map((item) => item.value), [
      60,
      68,
      55,
      41,
      35,
      30,
    ]);
    expect(profile.totalScore, 48);
    expect(StudentProfile(user: user, indicators: []).totalScore, 0);
    expect(
      StudentProfile(
        user: user,
        indicators: [
          StudentIndicator(name: 'A', value: 0),
          StudentIndicator(name: 'B', value: 99),
        ],
      ).totalScore,
      50,
    );
    expect(StudentIndicator(name: 'A', value: 100).value, 100);
    for (final value in [-1, 101]) {
      expect(() => StudentIndicator(name: 'A', value: value), throwsRangeError);
    }
  });

  testWidgets('Profile shows account, count and six progress bars on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final preferences = AchievementPreferences();
    final service = LocalAchievementService(
      login: user.login,
      preferences: preferences,
    );
    final profile = StudentProfile.initial(user);

    Future<void> openProfile() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ProfileScreen(profile: profile, achievementService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await openProfile();
    expect(find.text('Әли Ермек'), findsOneWidget);
    expect(find.text('ali@example.kz'), findsOneWidget);
    expect(find.text('Көрсетілмеген'), findsNWidgets(3));
    expect(find.text('Жетістіктер саны: 0'), findsOneWidget);
    expect(find.text('Жалпы балл: 48'), findsOneWidget);
    expect(
      tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .map((bar) => bar.value),
      [0.6, 0.68, 0.55, 0.41, 0.35, 0.3],
    );
    for (final indicator in profile.indicators) {
      await tester.ensureVisible(find.text(indicator.name));
      expect(find.text('${indicator.value} / 100'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await service.add(
      Achievement(
        title: 'Жоба',
        description: 'Сипаттама',
        category: 'Projects',
        date: DateTime(2026, 10, 8),
      ),
    );
    final other = LocalAchievementService(
      login: 'other',
      preferences: preferences,
    );
    await other.add(
      Achievement(
        title: 'Басқа',
        description: 'Сипаттама',
        category: 'Sport',
        date: DateTime(2026, 10, 8),
      ),
    );
    await openProfile();
    expect(find.text('Жетістіктер саны: 1'), findsOneWidget);
    expect(find.text('Жалпы балл: 48'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    preferences.failReads = true;
    await openProfile();
    expect(
      find.text('Жетістіктер санын жүктеу мүмкін болмады.'),
      findsOneWidget,
    );
    expect(find.text('Жетістіктер саны: 0'), findsNothing);
    preferences.failReads = false;
    await tester.ensureVisible(find.text('Қайта көру'));
    await tester.tap(find.text('Қайта көру'));
    await tester.pumpAndSettle();
    expect(find.text('Жетістіктер саны: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
