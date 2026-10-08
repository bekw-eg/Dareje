import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/screens/achievements_screen.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/utils/achievement_date.dart';
import 'package:student_achievements/utils/app_theme.dart';

// Тестовое хранилище позволяет включать сбои между попытками сохранения.
// ignore: must_be_immutable
class AchievementPreferences implements SharedPreferencesAsync {
  final values = <String, String>{};
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> getString(String key) async {
    if (failReads) throw StateError('Read failed');
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('Write failed');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AchievementPreferences preferences;
  late LocalAchievementService service;
  final achievement = Achievement(
    title: 'Олимпиада',
    description: 'Бірінші орын',
    category: 'Programming',
    date: DateTime(2026, 10, 8),
  );

  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    preferences = AchievementPreferences();
    service = LocalAchievementService(
      login: 'student',
      preferences: preferences,
    );
  });

  test('Persistence across instances, account isolation and append', () async {
    expect(await service.load(), isEmpty);
    await service.add(achievement);
    final restarted = LocalAchievementService(
      login: 'student',
      preferences: preferences,
    );
    expect((await restarted.load()).single.toJson(), achievement.toJson());
    final other = LocalAchievementService(
      login: 'other',
      preferences: preferences,
    );
    expect(await other.load(), isEmpty);
    await other.add(achievement);
    await restarted.add(
      Achievement(
        title: 'Жоба',
        description: 'Жаңа жоба',
        category: 'Projects',
        date: DateTime(2026, 10, 9),
      ),
    );
    expect((await restarted.load()).map((item) => item.title), [
      'Жоба',
      'Олимпиада',
    ]);
    expect((await other.load()).length, 1);
  });

  test('Failed writes and corrupt storage preserve existing data', () async {
    await service.add(achievement);
    final saved = Map<String, String>.from(preferences.values);
    preferences.failWrites = true;
    await expectLater(service.add(achievement), throwsStateError);
    expect(preferences.values, saved);
    preferences.failWrites = false;
    preferences.values[preferences.values.keys.single] = 'broken json';
    await expectLater(service.add(achievement), throwsFormatException);
    expect(preferences.values.values.single, 'broken json');
  });

  test('Date validation handles nonexistent dates and leap years', () {
    for (final value in [
      '',
      '31.04.2026',
      '29.02.2025',
      '00.01.2026',
      '01.13.2026',
      '01.01.0000',
      '2026-10-08',
    ]) {
      expect(parseAchievementDate(value), isNull, reason: value);
    }
    expect(parseAchievementDate('29.02.2024'), DateTime(2024, 2, 29));
    expect(formatAchievementDate(DateTime(2026, 10, 8)), '08.10.2026');
  });

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: AchievementsScreen(service: service)),
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

  testWidgets('Form validation, save retry, card and reload on narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openScreen(tester);
    expect(find.text('Әзірге жетістіктер жоқ'), findsOneWidget);
    await tester.tap(find.text('Жетістік қосу'));
    await tester.pumpAndSettle();
    await tapSave(tester);
    expect(find.text('Жетістік атауын енгізіңіз'), findsOneWidget);
    expect(preferences.values, isEmpty);
    final fields = find.byType(TextFormField);
    for (final entry in [
      (0, 'Олимпиада'),
      (1, 'Бірінші орын'),
      (2, '08.10.2026'),
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
    expect(preferences.values, isEmpty);
    preferences.failWrites = false;
    await tapSave(tester);
    expect(find.text('Әзірге жетістіктер жоқ'), findsNothing);
    for (final value in [
      'Олимпиада',
      'Бірінші орын',
      'Programming',
      '08.10.2026',
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect((await service.load()).single.toJson(), achievement.toJson());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await openScreen(tester);
    expect(find.text('Олимпиада'), findsOneWidget);
  });

  testWidgets('Cancel does not save a draft', (tester) async {
    await openScreen(tester);
    await tester.tap(find.text('Жетістік қосу'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Draft');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Әзірге жетістіктер жоқ'), findsOneWidget);
    expect(await service.load(), isEmpty);
  });

  testWidgets('Read failure offers retry instead of an empty state', (
    tester,
  ) async {
    preferences.failReads = true;
    await openScreen(tester);
    expect(find.text('Жетістіктерді жүктеу мүмкін болмады.'), findsOneWidget);
    expect(find.text('Жетістік қосу'), findsNothing);
    preferences.failReads = false;
    await tester.tap(find.text('Қайта көру'));
    await tester.pumpAndSettle();
    expect(find.text('Әзірге жетістіктер жоқ'), findsOneWidget);
  });
}
