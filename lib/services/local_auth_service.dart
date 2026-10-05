import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_user.dart';
import '../utils/auth_validators.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

// Учебная локальная авторизация. Для общих аккаунтов на разных устройствах
// позже понадобится серверная авторизация.
class LocalAuthService extends ChangeNotifier {
  LocalAuthService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const storageKey = 'dareje.auth.v1';
  final SharedPreferencesAsync _preferences;
  List<LocalUser> _users = [];
  LocalUser? _currentUser;

  LocalUser? get currentUser => _currentUser;

  Future<void> load() async {
    final saved = await _preferences.getString(storageKey);
    if (saved == null) return;
    final data = jsonDecode(saved) as Map<String, dynamic>;
    final users = (data['users'] as List<dynamic>)
        .map((user) => LocalUser.fromJson(user as Map<String, dynamic>))
        .toList();
    final activeLogin = data['activeLogin'] as String?;
    _users = users;
    _currentUser = null;
    for (final user in users) {
      if (user.login == activeLogin) _currentUser = user;
    }
    notifyListeners();
  }

  Future<void> register({
    required String login,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final error =
        AuthValidators.login(login) ??
        AuthValidators.name(firstName) ??
        AuthValidators.name(lastName) ??
        AuthValidators.email(email) ??
        AuthValidators.password(password);
    if (error != null) throw AuthException(error);
    final normalizedLogin = login.trim().toLowerCase();
    final normalizedEmail = email.trim().toLowerCase();
    if (_users.any((user) => user.login == normalizedLogin)) {
      throw const AuthException('Бұл логин бос емес. Басқа логин таңдаңыз');
    }
    if (_users.any((user) => user.email == normalizedEmail)) {
      throw const AuthException('Бұл пошта тіркелген. Аккаунтыңызға кіріңіз');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final user = LocalUser(
      login: normalizedLogin,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: normalizedEmail,
      passwordHash: await _hashPassword(password, salt),
      salt: base64Encode(salt),
    );
    final users = [..._users, user];
    // Аккаунт и сессию сохраняем вместе; интерфейс обновляем после записи.
    await _save(users, user.login);
    _users = users;
    _currentUser = user;
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    final normalized = identifier.trim().toLowerCase();
    LocalUser? account;
    for (final user in _users) {
      if (user.login == normalized || user.email == normalized) {
        account = user;
        break;
      }
    }
    if (account == null ||
        await _hashPassword(password, base64Decode(account.salt)) !=
            account.passwordHash) {
      throw const AuthException('Логин, пошта немесе құпия сөз қате');
    }
    await _save(_users, account.login);
    _currentUser = account;
    notifyListeners();
  }

  Future<void> logout() async {
    // Выход удаляет только сессию: зарегистрированные аккаунты остаются.
    await _save(_users, null);
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _save(List<LocalUser> users, String? activeLogin) =>
      _preferences.setString(
        storageKey,
        jsonEncode({
          'users': users.map((user) => user.toJson()).toList(),
          'activeLogin': activeLogin,
        }),
      );

  static Future<String> _hashPassword(String password, List<int> salt) async {
    // Пароль не храним открытым текстом. PBKDF2 использует отдельную соль.
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 600000,
      bits: 256,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return base64Encode(await key.extractBytes());
  }
}
