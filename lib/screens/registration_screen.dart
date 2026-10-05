import 'package:flutter/material.dart';

import '../services/local_auth_service.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_layout.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.authService});

  final LocalAuthService authService;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _login,
      _firstName,
      _lastName,
      _email,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (_isSubmitting) return;
    setState(() => _hasSubmitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.authService.register(
        login: _login.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Аккаунт сақталмады. Қайта көріңіз');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AuthLayout(
        showBackButton: true,
        canGoBack: !_isSubmitting,
        title: 'Аккаунт құру',
        description: 'Өзіңіз туралы мәліметтерді енгізіп, Dáreje-ге қосылыңыз.',
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
                  controller: _login,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.newUsername],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Логин',
                    hintText: 'bekw-eg',
                    helperText: 'Латын әріптері, сандар және дефис (-)',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: AuthValidators.login,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _firstName,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.givenName],
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Аты',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: AuthValidators.name,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _lastName,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.familyName],
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Тегі',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: AuthValidators.name,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _email,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Электрондық пошта',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: AuthValidators.email,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _password,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.newPassword],
                  obscureText: _hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Құпия сөз',
                    helperText: 'Кемінде 8 таңба: әріптер немесе сандар',
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
                  validator: AuthValidators.password,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _confirmation,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.newPassword],
                  obscureText: _hideConfirmation,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: InputDecoration(
                    labelText: 'Құпия сөзді қайталаңыз',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _hideConfirmation
                          ? 'Құпия сөзді көрсету'
                          : 'Құпия сөзді жасыру',
                      onPressed: () => setState(
                        () => _hideConfirmation = !_hideConfirmation,
                      ),
                      icon: Icon(
                        _hideConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Құпия сөзді қайталаңыз';
                    }
                    if (value != _password.text) {
                      return 'Құпия сөздер сәйкес келмейді';
                    }
                    return null;
                  },
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
                  onPressed: _isSubmitting ? null : _register,
                  child: Text(_isSubmitting ? 'Сақталуда…' : 'Тіркелу'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Аккаунтыңыз бар ма?'),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Кіру'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
