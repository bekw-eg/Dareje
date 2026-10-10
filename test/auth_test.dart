import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:student_achievements/main.dart';
import 'package:student_achievements/services/local_auth_service.dart';
import 'package:student_achievements/utils/auth_validators.dart';

// Подменяем только хранилище: настоящие проверки пароля и сессии остаются.
class MemoryPreferences implements SharedPreferencesAsync {
  MemoryPreferences({
    String? saved,
    this.failReads = false,
    this.failWrites = false,
  }) : values = {if (saved != null) LocalAuthService.storageKey: saved};

  final Map<String, String> values;
  final bool failReads;
  final bool failWrites;

  @override
  Future<String?> getString(String key) async {
    if (failReads) throw StateError('Storage unavailable');
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('Storage unavailable');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String savedAccount;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final preferences = MemoryPreferences();
    final auth = LocalAuthService(preferences: preferences);
    await auth.register(
      login: 'Bekw-eg12',
      firstName: 'Бек',
      lastName: 'Ермек',
      email: 'Bek@example.kz',
      password: 'Password12',
    );
    expect(auth.currentUser?.login, 'bekw-eg12');
    savedAccount = preferences.values[LocalAuthService.storageKey]!;
    auth.dispose();
  });

  test('Login allows letters, numbers and hyphens only', () {
    expect(AuthValidators.login('bekw-eg12'), isNull);
    for (final value in ['', 'bekw eg', 'bekw_eg', 'бек', '/#@!\$%^&']) {
      expect(AuthValidators.login(value), isNotNull, reason: value);
    }
  });

  test('Email requires a complete address', () {
    expect(AuthValidators.email('example.com@xxx.xxx'), isNull);
    expect(AuthValidators.email('bek.eg+study@school.kz'), isNull);
    for (final value in [
      '',
      'bek@',
      '@school.kz',
      'bek@school',
      'b e@school.kz',
      'bek@-school.kz',
      'bek..eg@school.kz',
    ]) {
      expect(AuthValidators.email(value), isNotNull, reason: value);
    }
  });

  test('Password needs eight characters and includes letters or numbers', () {
    for (final value in [
      '12345678',
      'abcdefgh',
      'Пароль12',
      'Құпиясөз',
      'Password!',
    ]) {
      expect(AuthValidators.password(value), isNull, reason: value);
    }
    for (final value in ['', 'abc1234', '        ', '!!!!!!!!']) {
      expect(AuthValidators.password(value), isNotNull, reason: value);
    }
  });

  test('Registration persists all details without the plaintext password', () {
    final data = jsonDecode(savedAccount) as Map<String, dynamic>;
    final account =
        (data['users'] as List<dynamic>).single as Map<String, dynamic>;
    expect(account['firstName'], 'Бек');
    expect(account['lastName'], 'Ермек');
    expect(account['email'], 'bek@example.kz');
    expect(account['passwordHash'], isNotEmpty);
    expect(account['salt'], isNotEmpty);
    expect(savedAccount, isNot(contains('Password12')));
  });

  test(
    'A new app instance restores the session and logout preserves the account',
    () async {
      final preferences = MemoryPreferences(saved: savedAccount);
      final auth = LocalAuthService(preferences: preferences);
      await auth.load();
      expect(auth.currentUser?.login, 'bekw-eg12');
      await auth.logout();
      final restarted = LocalAuthService(preferences: preferences);
      await restarted.load();
      expect(restarted.currentUser, isNull);
      await restarted.login(' BEK@EXAMPLE.KZ ', 'Password12');
      expect(restarted.currentUser?.firstName, 'Бек');
      await restarted.logout();
      await restarted.login('BEKW-EG12', 'Password12');
      expect(restarted.currentUser?.email, 'bek@example.kz');
      auth.dispose();
      restarted.dispose();
    },
  );

  test('Wrong credentials cannot start a session', () async {
    final auth = LocalAuthService(
      preferences: MemoryPreferences(saved: savedAccount),
    );
    await auth.load();
    await auth.logout();
    await expectLater(
      auth.login('bekw-eg12', 'Wrong123'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      auth.login('missing-user', 'Password12'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.currentUser, isNull);
    auth.dispose();
  });

  test('Duplicate login and email are rejected regardless of case', () async {
    final auth = LocalAuthService(
      preferences: MemoryPreferences(saved: savedAccount),
    );
    await auth.load();
    for (final values in [
      ('BEKW-EG12', 'other@example.kz'),
      ('other-user', 'BEK@EXAMPLE.KZ'),
    ]) {
      await expectLater(
        auth.register(
          login: values.$1,
          firstName: 'Бек',
          lastName: 'Ермек',
          email: values.$2,
          password: 'Password12',
        ),
        throwsA(isA<AuthException>()),
      );
    }
    auth.dispose();
  });

  test('Failed session write keeps the current signed-in user', () async {
    final auth = LocalAuthService(
      preferences: MemoryPreferences(saved: savedAccount, failWrites: true),
    );
    await auth.load();
    await expectLater(auth.logout(), throwsStateError);
    expect(auth.currentUser?.login, 'bekw-eg12');
    auth.dispose();
  });

  testWidgets('Startup restores the home screen, logout returns to login', (
    tester,
  ) async {
    final auth = LocalAuthService(
      preferences: MemoryPreferences(saved: savedAccount),
    );
    await tester.pumpWidget(StudentApp(authService: auth));
    await tester.pumpAndSettle();
    expect(find.text('Сәлем, Бек!'), findsOneWidget);
    expect(find.text('Жалпы балл: 48'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Бек Ермек'), findsOneWidget);
    expect(find.text('bek@example.kz'), findsOneWidget);
    expect(find.text('Көрсеткіштер'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.leaderboard_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Сәлем, Бек!'), findsOneWidget);
    await tester.tap(find.text('Шығу'));
    await tester.pumpAndSettle();
    expect(find.text('Қош келдіңіз!'), findsOneWidget);
    expect(find.text('Сәлем, Бек!'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets(
    'Registration validates confirmation on a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = LocalAuthService(preferences: MemoryPreferences());
      await tester.pumpWidget(StudentApp(authService: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Тіркелу'));
      await tester.tap(find.text('Тіркелу'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(6));
      for (var index = 0; index < 6; index++) {
        final field = fields.at(index);
        await tester.ensureVisible(field);
        await tester.enterText(
          field,
          [
            'bekw-eg',
            'Бек',
            'Ермек',
            'bek@example.kz',
            'Password12',
            'Different12',
          ][index],
        );
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Тіркелу'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Тіркелу'));
      await tester.pumpAndSettle();
      expect(find.text('Құпия сөздер сәйкес келмейді'), findsOneWidget);
      expect(auth.currentUser, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );

  testWidgets(
    'Storage read failure offers a retry instead of bypassing login',
    (tester) async {
      final auth = LocalAuthService(
        preferences: MemoryPreferences(failReads: true),
      );
      await tester.pumpWidget(StudentApp(authService: auth));
      await tester.pumpAndSettle();
      expect(find.text('Қайта көру'), findsOneWidget);
      expect(find.text('Басты бет'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
}
