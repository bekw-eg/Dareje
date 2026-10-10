import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/local_user.dart';
import 'package:student_achievements/screens/main_screen.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/services/local_auth_service.dart';
import 'package:student_achievements/utils/app_theme.dart';

import 'achievements_test.dart' show AchievementPreferences;
import 'auth_test.dart' show MemoryPreferences;

void main() {
  const user = LocalUser(
    login: 'student',
    firstName: 'Әли',
    lastName: 'Ермек',
    email: 'ali@example.kz',
    passwordHash: '',
    salt: '',
  );
  late LocalAuthService auth;
  late AchievementPreferences preferences;
  late LocalAchievementService achievements;

  setUp(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    auth = LocalAuthService(
      preferences: MemoryPreferences(
        saved: jsonEncode({
          'users': [user.toJson()],
          'activeLogin': user.login,
        }),
      ),
    );
    await auth.load();
    preferences = AchievementPreferences();
    achievements = LocalAchievementService(
      login: user.login,
      preferences: preferences,
    );
  });

  tearDown(() => auth.dispose());

  Future<void> openMain(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainScreen(authService: auth, achievementService: achievements),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Сақтау');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Save updates both screens and restart never adds points twice', (
    tester,
  ) async {
    await openMain(tester);
    expect(find.text('Жалпы балл: 48'), findsOneWidget);
    await tester.tap(find.text('Жетістік қосу'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Жетістік қосу'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    for (final entry in [
      (0, 'Hackathon Winner'),
      (1, 'Бірінші орын'),
      (2, '10.10.2026'),
    ]) {
      await tester.ensureVisible(fields.at(entry.$1));
      await tester.enterText(fields.at(entry.$1), entry.$2);
      await tester.pumpAndSettle();
    }
    final category = find.byType(DropdownButton<String>);
    await tester.ensureVisible(category);
    await tester.pumpAndSettle();
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programming').last);
    await tester.pumpAndSettle();

    preferences.failWrites = true;
    await tapSave(tester);
    expect(find.text('Жетістік сақталмады. Қайта көріңіз'), findsOneWidget);
    expect(await achievements.load(), isEmpty);
    preferences.failWrites = false;
    await tapSave(tester);
    expect(find.text('Hackathon Winner'), findsOneWidget);
    expect((await achievements.load()).length, 1);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Жалпы балл: 51'), findsOneWidget);
    expect(find.text('Жетістіктер саны: 1'), findsOneWidget);
    expect(
      tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .map((bar) => bar.value),
      [0.6, 0.78, 0.59, 0.41, 0.35, 0.3],
    );
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Жалпы балл: 51'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    achievements = LocalAchievementService(
      login: user.login,
      preferences: preferences,
    );
    await openMain(tester);
    expect(find.text('Жалпы балл: 51'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Жалпы балл: 51'), findsOneWidget);
    expect(find.text('Жетістіктер саны: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Existing achievements are loaded only for the current account', (
    tester,
  ) async {
    await achievements.add(
      Achievement(
        title: 'Еріктілік',
        description: 'Көмек',
        category: 'Volunteering',
        date: DateTime(2026, 10, 10),
      ),
    );
    final other = LocalAchievementService(
      login: 'other',
      preferences: preferences,
    );
    await other.add(
      Achievement(
        title: 'Жоба',
        description: 'Сипаттама',
        category: 'Projects',
        date: DateTime(2026, 10, 10),
      ),
    );
    await openMain(tester);
    expect(find.text('Жалпы балл: 51'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Жетістіктер саны: 1'), findsOneWidget);
    expect(
      tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .map((bar) => bar.value),
      [0.6, 0.68, 0.55, 0.46, 0.35, 0.4],
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Read failure offers retry without showing a false base score', (
    tester,
  ) async {
    await achievements.add(
      Achievement(
        title: 'Жоба',
        description: 'Сипаттама',
        category: 'Projects',
        date: DateTime(2026, 10, 10),
      ),
    );
    preferences.failReads = true;
    await openMain(tester);
    expect(find.text('Профильді жүктеу мүмкін болмады.'), findsOneWidget);
    expect(find.text('Жалпы балл: 48'), findsNothing);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Профильді жүктеу мүмкін болмады.'), findsOneWidget);
    preferences.failReads = false;
    await tester.tap(find.text('Қайта көру'));
    await tester.pumpAndSettle();
    expect(find.text('Жетістіктер саны: 1'), findsOneWidget);
    expect(find.text('Жалпы балл: 51'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Жалпы балл: 51'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
