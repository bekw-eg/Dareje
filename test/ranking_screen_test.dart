import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/screens/ranking_screen.dart';
import 'package:student_achievements/services/ranking_data_source.dart';
import 'package:student_achievements/utils/app_theme.dart';

import 'student_ranking_test.dart' show rankingProfile, rankingUser;

class TestRankingSource implements RankingDataSource {
  List<StudentProfile> profiles = [];
  bool failReads = false;
  Completer<List<StudentProfile>>? pending;

  @override
  Future<List<StudentProfile>> loadProfiles() async {
    if (pending != null) return pending!.future;
    if (failReads) throw StateError('Read failed');
    return profiles;
  }
}

void main() {
  late TestRankingSource source;

  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    source = TestRankingSource();
  });

  Future<void> openScreen(WidgetTester tester, {int revision = 0}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RankingScreen(
              dataSource: source,
              currentLogin: 'ali',
              dataRevision: revision,
            ),
          ),
        ),
      );

  testWidgets('Loading, empty state, error and successful retry', (
    tester,
  ) async {
    source.pending = Completer<List<StudentProfile>>();
    await openScreen(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    source.pending!.complete([]);
    source.pending = null;
    await tester.pumpAndSettle();
    expect(find.text('Рейтингте студенттер жоқ'), findsOneWidget);
    expect(find.text('Сіздің орныңыз'), findsNothing);
    expect(find.text('TOP-3'), findsNothing);

    source.failReads = true;
    await tester.tap(find.byTooltip('Жаңарту'));
    await tester.pumpAndSettle();
    expect(find.text('Рейтингті жүктеу мүмкін болмады'), findsOneWidget);
    expect(find.text('Рейтингте студенттер жоқ'), findsNothing);
    source.failReads = false;
    source.profiles = [StudentProfile.initial(rankingUser('ali'))];
    await tester.tap(find.text('Қайта көру'));
    await tester.pumpAndSettle();
    expect(find.text('Әзірге басқа студенттер жоқ'), findsOneWidget);
    expect(find.text('Сіздің орныңыз'), findsOneWidget);
    expect(find.text('48 балл'), findsWidgets);
    expect(find.text('TOP-3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tied TOP-3 keeps all shared places and opens real indicators', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    source.profiles = [
      rankingProfile('ali', 90),
      rankingProfile('b', 90),
      rankingProfile('c', 80),
      rankingProfile('d', 80),
      rankingProfile('e', 60),
    ];
    await openScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('TOP-3'), findsOneWidget);
    expect(
      find.text('#1'),
      findsNWidgets(5),
    ); // Own card, two leaders and two rows.
    expect(find.text('#3'), findsNWidgets(4));
    expect(find.text('#5'), findsOneWidget);
    final ownRow = find.byKey(const ValueKey('student-ali'));
    final card = tester.widget<Card>(
      find.descendant(of: ownRow, matching: find.byType(Card)),
    );
    expect(card.color, AppTheme.light.colorScheme.primaryContainer);
    await tester.tap(find.text('Көрсеткіштерді көру'));
    await tester.pumpAndSettle();
    expect(find.text('Әли Ермек'), findsOneWidget);
    expect(find.text('Жалпы балл: 90'), findsOneWidget);
    expect(find.text('90 / 100'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('TOP-3'), findsOneWidget);
    final otherRow = find.byKey(const ValueKey('student-c'));
    await tester.ensureVisible(otherRow);
    await tester.tap(otherRow);
    await tester.pumpAndSettle();
    expect(find.text('Жалпы балл: 80'), findsOneWidget);
    expect(find.text('c@example.kz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pull-to-refresh reads new data and handles a failed read', (
    tester,
  ) async {
    source.profiles = [StudentProfile.initial(rankingUser('ali'))];
    await openScreen(tester);
    await tester.pumpAndSettle();
    source.profiles = [rankingProfile('ali', 56)];
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('56 балл'), findsWidgets);
    expect(find.text('48 балл'), findsNothing);
    source.failReads = true;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Рейтингті жүктеу мүмкін болмады'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Data revision and manual refresh update own place and score', (
    tester,
  ) async {
    source.profiles = [rankingProfile('ali', 48), rankingProfile('aidana', 51)];
    await openScreen(tester);
    await tester.pumpAndSettle();
    final ownCard = find.ancestor(
      of: find.text('Сіздің орныңыз'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: ownCard, matching: find.text('#2')),
      findsOneWidget,
    );
    source.profiles = [rankingProfile('ali', 56), rankingProfile('aidana', 51)];
    await openScreen(tester, revision: 1);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: ownCard, matching: find.text('#1')),
      findsOneWidget,
    );
    expect(find.text('56 балл'), findsWidgets);
    expect(find.text('48 балл'), findsNothing);

    source.profiles = [rankingProfile('ali', 60), rankingProfile('aidana', 51)];
    await tester.tap(find.byTooltip('Жаңарту'));
    await tester.pumpAndSettle();
    expect(find.text('60 балл'), findsWidgets);
    expect(find.text('56 балл'), findsNothing);
    source.failReads = true;
    await tester.tap(find.byTooltip('Жаңарту'));
    await tester.pumpAndSettle();
    expect(find.text('Рейтингті жүктеу мүмкін болмады'), findsOneWidget);
    expect(find.text('60 балл'), findsNothing);
  });

  testWidgets(
    'Absent own account and unavailable indicators show no invented data',
    (tester) async {
      source.profiles = [
        StudentProfile(user: rankingUser('other'), indicators: []),
      ];
      await openScreen(tester);
      await tester.pumpAndSettle();
      expect(find.text('Сіздің аккаунтыңыз бұл тізімде жоқ.'), findsOneWidget);
      expect(find.text('Сіздің орныңыз'), findsNothing);
      final row = find.byKey(const ValueKey('student-other'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 640), const Size(1200, 800)]) {
    testWidgets('Responsive leaderboard at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      source.profiles = [
        StudentProfile.initial(rankingUser('ali')),
        StudentProfile.initial(rankingUser('aidana')),
        StudentProfile.initial(rankingUser('other-student-with-long-login')),
      ];
      await openScreen(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('TOP-3'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('student-other-student-with-long-login')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
