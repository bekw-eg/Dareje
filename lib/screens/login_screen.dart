import 'package:flutter/material.dart';

import '../services/local_auth_service.dart';
import '../widgets/auth_layout.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final LocalAuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isSubmitting) return;
    setState(() => _hasSubmitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.authService.login(_identifier.text, _password.text);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Кіру сақталмады. Қайта көріңіз');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Қош келдіңіз!',
      description: 'Жетістіктеріңізге бір қадам жақын. Аккаунтыңызға кіріңіз.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _hasSubmitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _identifier,
                enabled: !_isSubmitting,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Логин немесе пошта',
                  hintText: 'bekw-eg немесе name@example.com',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Логинді немесе поштаны енгізіңіз'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _password,
                enabled: !_isSubmitting,
                autofillHints: const [AutofillHints.password],
                obscureText: _hidePassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Құпия сөз',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword
                        ? 'Құпия сөзді көрсету'
                        : 'Құпия сөзді жасыру',
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Құпия сөзді енгізіңіз'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _login,
                child: Text(_isSubmitting ? 'Кіруде…' : 'Кіру'),
              ),
              const SizedBox(height: 16),
              Text(
                'Келесі жолы автоматты түрде кіресіз.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Аккаунтыңыз жоқ па?'),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => RegistrationScreen(
                                  authService: widget.authService,
                                ),
                              ),
                            );
                          },
                    child: const Text('Тіркелу'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
