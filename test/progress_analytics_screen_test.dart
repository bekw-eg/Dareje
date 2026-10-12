import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/progress_analytics.dart';
import 'package:student_achievements/models/progress_history_entry.dart';
import 'package:student_achievements/models/student_indicator.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/screens/progress_analytics_screen.dart';
import 'package:student_achievements/services/analytics_data_source.dart';
import 'package:student_achievements/utils/app_theme.dart';
import 'package:student_achievements/widgets/analytics_charts.dart';

import 'student_ranking_test.dart' show rankingUser;

class TestAnalyticsSource implements AnalyticsDataSource {
  late ProgressAnalyticsData data;
  bool failReads = false;
  Completer<ProgressAnalyticsData>? pending;

  @override
  Future<ProgressAnalyticsData> load() async {
    if (pending != null) return pending!.future;
    if (failReads) throw StateError('Read failed');
    return data;
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 12, 12);
  final base = StudentProfile.initial(rankingUser('ali'));
  late TestAnalyticsSource source;
  ProgressAnalyticsData data(List<ProgressHistoryEntry> events) =>
      ProgressAnalyticsData(
        profile: base,
        achievements: [],
        history: events,
        rankingPosition: 2,
      );
  ProgressHistoryEntry event(String id, int days, int score) =>
      ProgressHistoryEntry(
        id: id,
        timestamp: now.subtract(Duration(days: days)),
        previousTotalScore: score - 2,
        newTotalScore: score,
        indicatorChanges: {StudentIndicatorType.academic: 10},
      );

  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    source = TestAnalyticsSource()..data = data([]);
  });

  Future<void> open(
    WidgetTester tester, {
    int revision = 0,
    ThemeData? theme,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize / tester.view.devicePixelRatio,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: ProgressAnalyticsScreen(
            dataSource: source,
            dataRevision: revision,
            clock: () => now,
          ),
        ),
      ),
    ),
  );

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Loading, error, retry, true overview and empty history', (
    tester,
  ) async {
    source.pending = Completer<ProgressAnalyticsData>();
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    source.pending!.completeError(StateError('Read failed'));
    source.pending = null;
    await tester.pumpAndSettle();
    expect(find.text('Талдауды жүктеу мүмкін болмады'), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-score')), findsNothing);
    await tester.tap(find.text('Қайта көру'));
    await tester.pumpAndSettle();
    expect(find.text('48 / 100'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('— балл'), findsOneWidget);
    await scrollTo(tester, find.text('Әзірге прогресс тарихы жоқ'));
    expect(find.byType(ProgressLineChart), findsNothing);
    await scrollTo(tester, find.text('Әзірге жетістіктер жоқ'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Radar interaction, line point selection, all filters and revision reload',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      source.data = data([
        event('old', 100, 48),
        event('30', 30, 50),
        event('7', 7, 52),
        event('new', 1, 54),
      ]);
      await open(tester);
      await tester.pumpAndSettle();
      final sport = find.widgetWithText(ChoiceChip, '5. Спорт 35');
      await tester.ensureVisible(sport);
      await tester.tap(sport);
      await tester.pumpAndSettle();
      expect(find.text('Спорт · 35 / 100'), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('progress-line-chart')));
      expect(find.textContaining('52 → 54 балл'), findsOneWidget);
      await tester.tap(find.byTooltip('Алдыңғы жазба'));
      await tester.pumpAndSettle();
      expect(find.textContaining('50 → 52 балл'), findsOneWidget);
      final chart = tester.getRect(
        find.byKey(const ValueKey('progress-line-chart')),
      );
      await tester.tapAt(Offset(chart.left + 40, chart.center.dy));
      await tester.pumpAndSettle();
      expect(find.textContaining('48 → 50 балл'), findsOneWidget);

      for (final pair in [
        ('7 күн', 2),
        ('30 күн', 3),
        ('90 күн', 3),
        ('Барлығы', 4),
      ]) {
        await tester.scrollUntilVisible(
          find.widgetWithText(ChoiceChip, pair.$1),
          -500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, pair.$1));
        await tester.pumpAndSettle();
        await scrollTo(
          tester,
          find.byKey(const ValueKey('progress-line-chart')),
        );
        expect(
          tester
              .widget<ProgressLineChart>(find.byType(ProgressLineChart))
              .events
              .length,
          pair.$2,
        );
      }
      source.data = data([]);
      await open(tester, revision: 1);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Әзірге прогресс тарихы жоқ'));
      expect(find.byType(ProgressLineChart), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Narrow screens, large text and dark color scheme avoid overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      source.data = data([event('one', 1, 50)]);
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
        for (var i = 0; i < 18; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('A period without events shows empty chart and recorded zero', (
    tester,
  ) async {
    source.data = data([event('old', 100, 48)]);
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('+0 балл'), findsOneWidget);
    await scrollTo(tester, find.text('Бұл кезеңде жазбалар жоқ'));
    expect(find.byType(ProgressLineChart), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
