import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/simulation_result.dart';
import 'package:student_achievements/models/student_indicator.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/screens/impact_simulator_screen.dart';
import 'package:student_achievements/screens/main_screen.dart';
import 'package:student_achievements/services/impact_simulation_data_source.dart';
import 'package:student_achievements/services/local_achievement_service.dart';
import 'package:student_achievements/services/local_auth_service.dart';
import 'package:student_achievements/utils/app_theme.dart';
import 'package:student_achievements/widgets/analytics_charts.dart';

import 'achievements_test.dart' show AchievementPreferences;
import 'auth_test.dart' show MemoryPreferences;
import 'student_ranking_test.dart' show rankingUser;

class TestSimulationSource implements ImpactSimulationDataSource {
  late ImpactSimulationData data;
  bool failReads = false;
  int reads = 0;
  Completer<ImpactSimulationData>? pending;
  @override
  Future<ImpactSimulationData> load() async {
    reads++;
    if (pending != null) return pending!.future;
    if (failReads) throw StateError('Read failed');
    return data;
  }
}

void main() {
  final base = StudentProfile.initial(rankingUser('ali'));
  late TestSimulationSource source;
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    source = TestSimulationSource()
      ..data = ImpactSimulationData(profile: base, rankingProfiles: [base]);
  });

  Future<void> open(
    WidgetTester tester, {
    ThemeData? theme,
    double textScale = 1,
    int revision = 0,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize / tester.view.devicePixelRatio,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: ImpactSimulatorScreen(
            dataSource: source,
            dataRevision: revision,
          ),
        ),
      ),
    ),
  );

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> simulate(WidgetTester tester, {String id = 'hackathon'}) async {
    await reveal(tester, find.byKey(ValueKey('scenario-$id')));
    await tester.tap(find.byKey(ValueKey('scenario-$id')));
    await reveal(tester, find.byKey(const ValueKey('simulate-impact')));
    await tester.tap(find.byKey(const ValueKey('simulate-impact')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Loading, error, retry, empty profile and disabled unselected scenario',
    (tester) async {
      source.pending = Completer<ImpactSimulationData>();
      await open(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      source.pending!.completeError(StateError('Read failed'));
      source.pending = null;
      await tester.pumpAndSettle();
      expect(find.text('Симуляторды жүктеу мүмкін болмады'), findsOneWidget);
      await tester.tap(find.text('Қайта көру'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('simulate-impact')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('simulate-impact')))
            .onPressed,
        isNull,
      );
      source.data = ImpactSimulationData(
        profile: StudentProfile(user: base.user, indicators: []),
      );
      await open(tester, revision: 1);
      await tester.pumpAndSettle();
      expect(find.text('Әзірге көрсеткіштер жоқ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Real before/after, animation, dual radar, toggles and independent rerun',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tester.pumpAndSettle();
      await simulate(tester);
      expect(source.reads, 2);
      expect(find.text('48 / 100'), findsOneWidget);
      expect(find.text('51 / 100'), findsOneWidget);
      expect(find.text('+3 жалпы балл'), findsOneWidget);
      expect(find.text('#1 → #1'), findsOneWidget);
      expect(
        find.textContaining('Әзірге басқа студенттер жоқ'),
        findsOneWidget,
      );
      final radar = tester.widget<SkillRadarChart>(
        find.byType(SkillRadarChart),
      );
      expect(radar.indicators.map((i) => i.value), [60, 68, 55, 41, 35, 30]);
      expect(radar.comparisonIndicators!.map((i) => i.value), [
        60,
        78,
        59,
        41,
        35,
        30,
      ]);
      final programming = find.widgetWithText(
        ChoiceChip,
        '2. Бағдарламалау 68',
      );
      await reveal(tester, programming);
      await tester.tap(programming);
      await tester.pumpAndSettle();
      expect(find.text('Бағдарламалау · 68 → 78 (+10)'), findsOneWidget);
      final metric = find.byKey(const ValueKey('impact-metric-programming'));
      await reveal(tester, metric);
      expect(tester.widget<Text>(metric).data, '78 / 100');
      final before = find.widgetWithText(ChoiceChip, 'Қазір');
      await tester.ensureVisible(before);
      await tester.tap(before);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final intermediate = tester.widget<Text>(metric).data!;
      expect(intermediate, isNot('78 / 100'));
      expect(intermediate, isNot('68 / 100'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(metric).data, '68 / 100');
      final after = find.widgetWithText(ChoiceChip, 'Болжам');
      await tester.tap(after);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(metric).data, '78 / 100');
      await reveal(tester, find.text('Балл неліктен өзгерді?'));
      expect(find.text('Топтық жұмыс: +0'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('try-another-scenario')));
      await tester.tap(find.byKey(const ValueKey('try-another-scenario')));
      await tester.pumpAndSettle();
      final category = find.byKey(const ValueKey('impact-category-Other'));
      await reveal(tester, category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await simulate(tester, id: 'student-event');
      expect(find.text('+1 жалпы балл'), findsOneWidget);
      expect(find.text('48 / 100'), findsOneWidget);
      expect(find.text('49 / 100'), findsOneWidget);
      expect(base.totalScore, 48);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All categories offer selectable scenarios, failed simulation retry and latest profile',
    (tester) async {
      await open(tester);
      await tester.pumpAndSettle();
      for (final category in Achievement.categories) {
        final chip = find.byKey(ValueKey('impact-category-$category'));
        await tester.scrollUntilVisible(
          chip,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(
          find
              .byType(InkWell)
              .evaluate()
              .where((e) => e.widget.key.toString().contains('scenario-'))
              .length,
          2,
        );
      }
      final programming = find.byKey(
        const ValueKey('impact-category-Programming'),
      );
      await tester.ensureVisible(programming);
      await tester.tap(programming);
      await tester.pumpAndSettle();
      source.failReads = true;
      await simulate(tester);
      expect(find.text('Симуляторды жүктеу мүмкін болмады'), findsOneWidget);
      source.failReads = false;
      source.data = ImpactSimulationData(
        profile: StudentProfile(
          user: base.user,
          indicators: [
            for (final item in base.indicators)
              // Новый реальный профиль, загруженный перед повторной попыткой.
              StudentIndicator(
                type: item.type,
                name: item.name,
                value: item.value + 10,
              ),
          ],
        ),
      );
      await tester.tap(find.text('Қайта көру'));
      await tester.pumpAndSettle();
      expect(find.text('Орын болжамы қолжетімсіз'), findsOneWidget);
      expect(find.text('+3 жалпы балл'), findsOneWidget);
      expect(find.text('58 / 100'), findsOneWidget);
      expect(find.text('61 / 100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Narrow layout, double text, both color schemes, saturation and no ranking',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      source.data = ImpactSimulationData(
        profile: StudentProfile(
          user: base.user,
          indicators: [
            for (final item in base.indicators)
              StudentIndicator(type: item.type, name: item.name, value: 100),
          ],
        ),
      );
      for (final theme in [
        AppTheme.light,
        ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF176B78),
            brightness: Brightness.dark,
          ),
        ),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await open(tester, theme: theme, textScale: 2);
        await tester.pumpAndSettle();
        await simulate(tester);
        for (var i = 0; i < 20; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'Main navigation returns unchanged; actual achievement updates next simulation',
    (tester) async {
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
      final preferences = AchievementPreferences();
      final achievements = LocalAchievementService(
        login: user.login,
        preferences: preferences,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainScreen(authService: auth, achievementService: achievements),
        ),
      );
      await tester.pumpAndSettle();
      final saved = Map<String, String>.from(preferences.values);
      await tester.ensureVisible(find.text('Ықпал симуляторы'));
      await tester.tap(find.text('Ықпал симуляторы'));
      await tester.pumpAndSettle();
      await simulate(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Жалпы балл: 48'), findsOneWidget);
      expect(preferences.values, saved);
      expect((await achievements.loadSnapshot()).history, isEmpty);
      await achievements.add(
        Achievement(
          title: 'Нақты',
          description: '',
          category: 'Programming',
          date: DateTime.utc(2026),
        ),
      );
      final afterSave = Map<String, String>.from(preferences.values);
      await tester.ensureVisible(find.text('Ықпал симуляторы'));
      await tester.tap(find.text('Ықпал симуляторы'));
      await tester.pumpAndSettle();
      await simulate(tester);
      expect(find.text('51 / 100'), findsOneWidget);
      expect(find.text('53 / 100'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(preferences.values, afterSave);
      expect((await achievements.loadSnapshot()).history.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
