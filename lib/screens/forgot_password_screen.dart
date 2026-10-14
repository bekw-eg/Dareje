import 'package:flutter/material.dart';

import '../services/local_auth_service.dart';
import '../utils/auth_validators.dart';
import '../widgets/app_widgets.dart';
import '../widgets/auth_layout.dart';
import '../widgets/recovery_code_dialog.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.authService,
    this.initialIdentifier = '',
  });

  final LocalAuthService authService;
  final String initialIdentifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _identifier = TextEditingController(
    text: widget.initialIdentifier,
  );
  final _recoveryCode = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _isSubmitting = false;
  bool _isShowingRecoveryCode = false;
  bool _hasSubmitted = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _identifier,
      _recoveryCode,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_isSubmitting) return;
    setState(() => _hasSubmitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final nextCode = await widget.authService.resetPassword(
        identifier: _identifier.text,
        recoveryCode: _recoveryCode.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(() => _isShowingRecoveryCode = true);
      await showRecoveryCodeDialog(
        context,
        code: nextCode,
        passwordWasReset: true,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Құпия сөз сақталмады. Қайта көріңіз');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isShowingRecoveryCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isSubmitting,
    child: AuthLayout(
      showBackButton: true,
      canGoBack: !_isSubmitting,
      title: 'Құпия сөзді қалпына келтіру',
      description: 'Тіркелгенде сақтаған резервтік кодты енгізіңіз.',
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
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Логинді немесе поштаны енгізіңіз'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _recoveryCode,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Қалпына келтіру коды',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Қалпына келтіру кодын енгізіңіз'
                    : null,
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
                  labelText: 'Жаңа құпия сөз',
                  helperText: 'Кемінде 8 таңба: әріптер немесе сандар',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _hidePassword = !_hidePassword),
                    tooltip: _hidePassword
                        ? 'Құпия сөзді көрсету'
                        : 'Құпия сөзді жасыру',
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
                onFieldSubmitted: (_) => _resetPassword(),
                decoration: InputDecoration(
                  labelText: 'Құпия сөзді қайталаңыз',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(
                            () => _hideConfirmation = !_hideConfirmation,
                          ),
                    tooltip: _hideConfirmation
                        ? 'Құпия сөзді көрсету'
                        : 'Құпия сөзді жасыру',
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
                  return value == _password.text
                      ? null
                      : 'Құпия сөздер сәйкес келмейді';
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
                onPressed: _isSubmitting ? null : _resetPassword,
                child: AppButtonContent(
                  busy: _isSubmitting && !_isShowingRecoveryCode,
                  label: 'Құпия сөзді жаңарту',
                  busyLabel: 'Сақталуда…',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Алғашқы код тіркелу кезінде беріледі, ал құпия сөз '
                'қалпына келтірілгенде жаңа код көрсетіледі. Бұрын тіркелген '
                'аккаунтта код болмаса немесе код жоғалса, құпия сөзді '
                'қалпына келтіру мүмкін емес. Поштаға хат жіберілмейді.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
