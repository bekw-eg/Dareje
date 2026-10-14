import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/main.dart';
import 'package:student_achievements/screens/forgot_password_screen.dart';
import 'package:student_achievements/services/local_auth_service.dart';
import 'package:student_achievements/utils/app_theme.dart';

import 'auth_test.dart' show MemoryPreferences;

// Здесь проверяем состояния формы; настоящий хеш и запись — в password_recovery_test.
class FormAuthService extends LocalAuthService {
  FormAuthService() : super(preferences: MemoryPreferences());

  static const code = 'ABCD-EFGH-JKLM-NPQR-STUV-WXYZ';
  Completer<String>? pendingReset;
  Object? resetError;
  int resetCalls = 0;
  String? identifier;
  String? recoveryCode;
  String? newPassword;

  @override
  Future<String> register({
    required String login,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async => code;

  @override
  Future<String> resetPassword({
    required String identifier,
    required String recoveryCode,
    required String newPassword,
  }) async {
    resetCalls++;
    this.identifier = identifier;
    this.recoveryCode = recoveryCode;
    this.newPassword = newPassword;
    if (resetError != null) throw resetError!;
    return pendingReset == null ? code : pendingReset!.future;
  }
}

Future<void> fillResetForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  for (var index = 0; index < 4; index++) {
    await tester.ensureVisible(fields.at(index));
    await tester.enterText(
      fields.at(index),
      ['student-one', FormAuthService.code, 'Updated12', 'Updated12'][index],
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, 'Құпия сөзді жаңарту'),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);

  testWidgets('Registration shows a code to copy before returning to login', (
    tester,
  ) async {
    final auth = FormAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(StudentApp(authService: auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Тіркелу'));
    await tester.tap(find.text('Тіркелу'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    for (var index = 0; index < 6; index++) {
      await tester.ensureVisible(fields.at(index));
      await tester.enterText(
        fields.at(index),
        [
          'student-one',
          'Али',
          'Ермек',
          'ali@example.kz',
          'Original12',
          'Original12',
        ][index],
      );
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Тіркелу'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Тіркелу'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SelectableText, FormAuthService.code),
      findsOneWidget,
    );
    expect(find.text('Аккаунт құру'), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          copied = call.arguments['text'] as String;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Кодты көшіру'));
    await tester.pumpAndSettle();
    expect(copied, FormAuthService.code);
    await tester.tap(find.text('Кодты сақтадым'));
    await tester.pumpAndSettle();
    expect(find.text('Қош келдіңіз!'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Both auth screens open recovery and prefill the identifier', (
    tester,
  ) async {
    final auth = FormAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(StudentApp(authService: auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(find.byType(TextFormField).first, 'ali@example.kz');
    await tester.ensureVisible(find.text('Құпиясөзді ұмыттыңыз ба?'));
    await tester.tap(find.text('Құпиясөзді ұмыттыңыз ба?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      'ali@example.kz',
    );
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Тіркелу'));
    await tester.tap(find.text('Тіркелу'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).at(3));
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'second@example.kz',
    );
    await tester.ensureVisible(find.text('Құпиясөзді ұмыттыңыз ба?'));
    await tester.tap(find.text('Құпиясөзді ұмыттыңыз ба?'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      'second@example.kz',
    );
    await fillResetForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Құпия сөзді жаңарту'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AlertDialog, 'Қалпына келтіру коды'),
      findsOneWidget,
    );
    await tester.tap(find.text('Кодты сақтадым'));
    await tester.pumpAndSettle();
    expect(find.text('Қош келдіңіз!'), findsOneWidget);
    expect(find.text('Аккаунт құру'), findsNothing);
    expect(auth.resetCalls, 1);
    expect(auth.newPassword, 'Updated12');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Recovery validates, blocks repeated submit and retries storage errors',
    (tester) async {
      final auth = FormAuthService();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ForgotPasswordScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Құпия сөзді жаңарту');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Қалпына келтіру кодын енгізіңіз'), findsOneWidget);
      expect(auth.resetCalls, 0);
      await fillResetForm(tester);
      await tester.enterText(find.byType(TextFormField).last, 'Different12');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Құпия сөздер сәйкес келмейді'), findsOneWidget);
      expect(auth.resetCalls, 0);
      await tester.enterText(find.byType(TextFormField).last, 'Updated12');
      auth.resetError = StateError('Storage unavailable');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Құпия сөз сақталмады. Қайта көріңіз'), findsOneWidget);
      auth.resetError = const AuthException(
        'Логин, пошта немесе қалпына келтіру коды қате',
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text('Логин, пошта немесе қалпына келтіру коды қате'),
        findsOneWidget,
      );
      auth.resetError = null;
      auth.pendingReset = Completer<String>();
      await tester.tap(button);
      await tester.pump();
      final calls = auth.resetCalls;
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        false,
      );
      final confirmation = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(TextField),
        ),
      );
      confirmation.onSubmitted!('Updated12');
      expect(auth.resetCalls, calls);
      auth.pendingReset!.complete(FormAuthService.code);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SelectableText, FormAuthService.code),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Recovery and its code dialog fit 320px with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FormAuthService();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 240),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: ForgotPasswordScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();
      await fillResetForm(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Құпия сөзді жаңарту'),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SelectableText, FormAuthService.code),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Кодты сақтадым'));
      await tester.tap(find.text('Кодты сақтадым'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
