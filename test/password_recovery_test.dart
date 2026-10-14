import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/services/local_auth_service.dart';

import 'auth_test.dart' show MemoryPreferences;

class RetryPreferences extends MemoryPreferences {
  RetryPreferences({required super.saved, required this.rejectWrites});

  final bool Function() rejectWrites;

  @override
  Future<void> setString(String key, String value) async {
    if (rejectWrites()) throw StateError('Storage unavailable');
    await super.setString(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String savedAccount;
  late String recoveryCode;

  setUpAll(() async {
    final preferences = MemoryPreferences();
    final auth = LocalAuthService(preferences: preferences);
    recoveryCode = await auth.register(
      login: 'student-one',
      firstName: 'Али',
      lastName: 'Ермек',
      email: 'ali@example.kz',
      password: 'Original12',
    );
    savedAccount = preferences.values[LocalAuthService.storageKey]!;
    auth.dispose();
  });

  test('Registration returns a random code and stores only its hash', () {
    expect(
      recoveryCode,
      matches(RegExp(r'^[A-HJ-NP-Z2-9]{4}(-[A-HJ-NP-Z2-9]{4}){5}$')),
    );
    final user = (jsonDecode(savedAccount)['users'] as List).single;
    expect(user['recoveryCodeHash'], isNotEmpty);
    expect(savedAccount, isNot(contains(recoveryCode)));
    expect(savedAccount, isNot(contains(recoveryCode.replaceAll('-', ''))));
    expect(savedAccount, isNot(contains('Original12')));
  });

  test(
    'Reset persists a fresh password and code, ends its session and preserves data',
    () async {
      final data = jsonDecode(savedAccount) as Map<String, dynamic>;
      final original = Map<String, dynamic>.from(data['users'][0] as Map);
      final other = {
        ...original,
        'login': 'other',
        'email': 'other@example.kz',
      };
      data['users'] = [original, other];
      final preferences = MemoryPreferences(saved: jsonEncode(data));
      preferences.values['dareje.achievements.v2.student-one'] =
          '{"achievements":[],"history":[]}';
      final auth = LocalAuthService(preferences: preferences);
      await auth.load();
      final nextCode = await auth.resetPassword(
        identifier: ' ALI@EXAMPLE.KZ ',
        recoveryCode: ' ${recoveryCode.toLowerCase().replaceAll('-', ' ')} ',
        newPassword: 'Updated12',
      );
      expect(auth.currentUser, isNull);
      expect(nextCode, isNot(recoveryCode));
      final saved = preferences.values[LocalAuthService.storageKey]!;
      final updatedData = jsonDecode(saved) as Map<String, dynamic>;
      final updated = updatedData['users'][0] as Map;
      for (final key in ['login', 'firstName', 'lastName', 'email']) {
        expect(updated[key], original[key]);
      }
      expect(updated['salt'], isNot(original['salt']));
      expect(updated['passwordHash'], isNot(original['passwordHash']));
      expect(updated['recoveryCodeHash'], isNot(original['recoveryCodeHash']));
      expect(updatedData['users'][1], other);
      expect(updatedData['activeLogin'], isNull);
      for (final secret in [
        nextCode,
        recoveryCode,
        'Updated12',
        'Original12',
      ]) {
        expect(saved, isNot(contains(secret)));
      }
      expect(
        preferences.values['dareje.achievements.v2.student-one'],
        '{"achievements":[],"history":[]}',
      );
      final restarted = LocalAuthService(preferences: preferences);
      await restarted.load();
      expect(restarted.currentUser, isNull);
      await expectLater(
        restarted.login('student-one', 'Original12'),
        throwsA(isA<AuthException>()),
      );
      await restarted.login('STUDENT-ONE', 'Updated12');
      expect(restarted.currentUser?.firstName, 'Али');
      await expectLater(
        restarted.resetPassword(
          identifier: 'student-one',
          recoveryCode: recoveryCode,
          newPassword: 'Rejected12',
        ),
        throwsA(isA<AuthException>()),
      );
      final thirdCode = await restarted.resetPassword(
        identifier: 'student-one',
        recoveryCode: nextCode,
        newPassword: 'Newest12',
      );
      expect(thirdCode, isNot(nextCode));
      expect(restarted.currentUser, isNull);
      auth.dispose();
      restarted.dispose();
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'Wrong credentials, short passwords and legacy accounts cannot reset',
    () async {
      final preferences = MemoryPreferences(saved: savedAccount);
      final auth = LocalAuthService(preferences: preferences);
      await auth.load();
      final errors = <String>[];
      for (final identifier in ['missing', 'student-one']) {
        try {
          await auth.resetPassword(
            identifier: identifier,
            recoveryCode: 'incorrect-code',
            newPassword: 'Updated12',
          );
          fail('Invalid recovery credentials must be rejected');
        } on AuthException catch (error) {
          errors.add(error.message);
        }
      }
      expect(errors[0], errors[1]);
      await expectLater(
        auth.resetPassword(
          identifier: 'student-one',
          recoveryCode: recoveryCode,
          newPassword: 'short',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(preferences.values[LocalAuthService.storageKey], savedAccount);
      expect(auth.currentUser?.login, 'student-one');
      final legacy = jsonDecode(savedAccount) as Map<String, dynamic>;
      (legacy['users'][0] as Map).remove('recoveryCodeHash');
      final legacyPreferences = MemoryPreferences(saved: jsonEncode(legacy));
      final legacyAuth = LocalAuthService(preferences: legacyPreferences);
      await legacyAuth.load();
      await expectLater(
        legacyAuth.resetPassword(
          identifier: 'ali@example.kz',
          recoveryCode: recoveryCode,
          newPassword: 'Updated12',
        ),
        throwsA(isA<AuthException>()),
      );
      await legacyAuth.login('student-one', 'Original12');
      expect(legacyAuth.currentUser?.login, 'student-one');
      expect(
        legacyPreferences.values[LocalAuthService.storageKey],
        isNot(contains('recoveryCodeHash')),
      );
      auth.dispose();
      legacyAuth.dispose();
    },
  );

  test(
    'Failed write preserves the old credentials and allows retry',
    () async {
      var rejectWrites = true;
      final preferences = RetryPreferences(
        saved: savedAccount,
        rejectWrites: () => rejectWrites,
      );
      final auth = LocalAuthService(preferences: preferences);
      await auth.load();
      final oldUser = auth.currentUser;
      await expectLater(
        auth.resetPassword(
          identifier: 'student-one',
          recoveryCode: recoveryCode,
          newPassword: 'Updated12',
        ),
        throwsStateError,
      );
      expect(auth.currentUser, same(oldUser));
      expect(auth.registeredUsers.single, same(oldUser));
      expect(preferences.values[LocalAuthService.storageKey], savedAccount);
      rejectWrites = false;
      await auth.login('student-one', 'Original12');
      await auth.resetPassword(
        identifier: 'student-one',
        recoveryCode: recoveryCode,
        newPassword: 'Updated12',
      );
      await auth.login('student-one', 'Updated12');
      expect(auth.currentUser?.login, 'student-one');
      auth.dispose();
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test('Concurrent resets cannot consume the same code twice', () async {
    final preferences = MemoryPreferences(saved: savedAccount);
    final auth = LocalAuthService(preferences: preferences);
    await auth.load();
    final first = auth.resetPassword(
      identifier: 'student-one',
      recoveryCode: recoveryCode,
      newPassword: 'FirstPass12',
    );
    await expectLater(
      auth.resetPassword(
        identifier: 'student-one',
        recoveryCode: recoveryCode,
        newPassword: 'SecondPass12',
      ),
      throwsA(isA<AuthException>()),
    );
    await first;
    await auth.login('student-one', 'FirstPass12');
    auth.dispose();
  });

  test(
    'Resetting another account preserves the unrelated active session',
    () async {
      final data = jsonDecode(savedAccount) as Map<String, dynamic>;
      final original = data['users'][0] as Map;
      data['users'] = [
        original,
        {...original, 'login': 'other', 'email': 'other@example.kz'},
      ];
      data['activeLogin'] = 'other';
      final preferences = MemoryPreferences(saved: jsonEncode(data));
      final auth = LocalAuthService(preferences: preferences);
      await auth.load();
      final other = auth.currentUser;
      await auth.resetPassword(
        identifier: 'student-one',
        recoveryCode: recoveryCode,
        newPassword: 'Updated12',
      );
      expect(auth.currentUser, same(other));
      expect(
        jsonDecode(
          preferences.values[LocalAuthService.storageKey]!,
        )['activeLogin'],
        'other',
      );
      auth.dispose();
    },
  );
}
