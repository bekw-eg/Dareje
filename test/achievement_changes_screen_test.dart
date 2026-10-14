import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/progress_history_entry.dart';
import 'package:student_achievements/screens/achievements_screen.dart';
import 'package:student_achievements/screens/add_achievement_screen.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/utils/app_theme.dart';

import 'achievements_test.dart' show AchievementPreferences;

class DelayedDeleteService extends LocalAchievementService {
  DelayedDeleteService({required super.preferences}) : super(login: 'ali');
  final pending = Completer<void>();
  int calls = 0;

  @override
  Future<void> delete(Achievement achievement) async {
    calls++;
    await pending.future;
    await super.delete(achievement);
  }
}

void main() {
  late AchievementPreferences preferences;
  late LocalAchievementService service;
  late Achievement original;
  var changes = 0;

  setUp(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    preferences = AchievementPreferences();
    service = LocalAchievementService(login: 'ali', preferences: preferences);
    original = Achievement(
      title: 'Хакатон',
      description: 'Бірінші орын',
      category: 'Programming',
      date: DateTime(2026, 10, 10),
    );
    await service.add(original);
    changes = 0;
  });

  Future<void> open(WidgetTester tester, {bool compact = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: compact
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 240),
                  disableAnimations: true,
                ),
                child: child!,
              )
            : null,
        home: Scaffold(
          body: AchievementsScreen(service: service, onSaved: () => changes++),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> action(WidgetTester tester, String label) async {
    final menu = find.byTooltip('Жетістік әрекеттері');
    if (menu.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        menu,
        240,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Сақтау');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Edit preloads all fields, validates and retries without duplicating',
    (tester) async {
      await open(tester);
      await action(tester, 'Өңдеу');
      expect(find.byType(AddAchievementScreen), findsOneWidget);
      final fields = find.byType(TextFormField);
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller?.text,
        original.title,
      );
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller?.text,
        original.description,
      );
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller?.text,
        '10.10.2026',
      );
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        'Programming',
      );
      await tester.ensureVisible(fields.first);
      await tester.enterText(fields.first, '');
      await save(tester);
      expect(find.text('Жетістік атауын енгізіңіз'), findsOneWidget);
      expect((await service.loadSnapshot()).history.length, 1);
      await tester.ensureVisible(fields.first);
      await tester.enterText(fields.first, 'Жаңа атау');
      await tester.ensureVisible(fields.at(1));
      await tester.enterText(fields.at(1), 'Жаңа сипаттама');
      await tester.ensureVisible(fields.at(2));
      await tester.enterText(fields.at(2), '12.10.2026');
      final dropdown = find.byType(DropdownButton<String>);
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Жобалар').last);
      await tester.pumpAndSettle();
      preferences.failWrites = true;
      await save(tester);
      expect(find.text('Жетістік сақталмады. Қайта көріңіз'), findsOneWidget);
      expect((await service.load()).single.toJson(), original.toJson());
      expect(changes, 0);
      preferences.failWrites = false;
      await save(tester);
      final snapshot = await service.loadSnapshot();
      expect(snapshot.achievements.single.id, original.id);
      expect(snapshot.achievements.single.title, 'Жаңа атау');
      expect(snapshot.achievements.single.description, 'Жаңа сипаттама');
      expect(snapshot.achievements.single.date, DateTime(2026, 10, 12));
      expect(snapshot.achievements.single.category, 'Projects');
      expect(snapshot.history.length, 2);
      expect(snapshot.history.last.operation, AchievementChange.update);
      expect(changes, 1);
      expect(find.text('Жаңа'), findsNothing);
      expect(find.byType(AddAchievementScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancel edit/delete keeps data; delete failure allows retry', (
    tester,
  ) async {
    final before = Map<String, String>.from(preferences.values);
    await open(tester);
    await action(tester, 'Өңдеу');
    await tester.enterText(find.byType(TextFormField).first, 'Несохранённое');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(preferences.values, before);
    expect(changes, 0);
    await action(tester, 'Өшіру');
    expect(find.text('Жетістікті өшіру керек пе?'), findsOneWidget);
    await tester.tap(find.text('Болдырмау'));
    await tester.pumpAndSettle();
    expect(preferences.values, before);
    expect(changes, 0);
    await action(tester, 'Өшіру');
    preferences.failWrites = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Өшіру'));
    await tester.pumpAndSettle();
    expect(find.text('Жетістік өшірілмеді. Қайта көріңіз'), findsOneWidget);
    expect(preferences.values, before);
    expect(changes, 0);
    preferences.failWrites = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Өшіру'));
    await tester.pumpAndSettle();
    expect(find.text('Әзірге жетістіктер жоқ'), findsOneWidget);
    expect((await service.load()).isEmpty, true);
    expect(
      (await service.loadSnapshot()).history.last.operation,
      AchievementChange.deletion,
    );
    expect(changes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Delete disables confirm and cancel while the write is pending', (
    tester,
  ) async {
    final delayed = DelayedDeleteService(preferences: preferences);
    service = delayed;
    await open(tester);
    await action(tester, 'Өшіру');
    final confirm = find.widgetWithText(FilledButton, 'Өшіру');
    final callback = tester.widget<FilledButton>(confirm).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(delayed.calls, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Болдырмау'))
          .onPressed,
      isNull,
    );
    expect((await delayed.load()).length, 1);
    delayed.pending.complete();
    await tester.pumpAndSettle();
    expect((await delayed.load()).isEmpty, true);
    expect(changes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Editing and delete confirmation fit 320px, double text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, compact: true);
      await action(tester, 'Өңдеу');
      final date = find.byType(TextFormField).last;
      await tester.ensureVisible(date);
      await tester.enterText(date, '31.04.2026');
      await save(tester);
      expect(
        find.text('Күнді КК.АА.ЖЖЖЖ форматында дұрыс енгізіңіз'),
        findsOneWidget,
      );
      await tester.ensureVisible(date);
      await tester.enterText(date, '12.10.2026');
      await save(tester);
      await action(tester, 'Өшіру');
      final cancel = find.text('Болдырмау');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect((await service.load()).single.date, DateTime(2026, 10, 12));
      expect(tester.takeException(), isNull);
    },
  );
}
