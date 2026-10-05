import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/local_auth_service.dart';
import 'utils/app_theme.dart';

void main() => runApp(const StudentApp());

class StudentApp extends StatefulWidget {
  const StudentApp({super.key, this.authService});

  final LocalAuthService? authService;

  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  late final LocalAuthService _authService;
  late Future<void> _loading;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? LocalAuthService();
    _loading = _authService.load();
  }

  @override
  void dispose() {
    if (widget.authService == null) _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dáreje',
      theme: AppTheme.light,
      home: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Сақталған аккаунтты оқу мүмкін болмады.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _loading = _authService.load()),
                        child: const Text('Қайта көру'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return ListenableBuilder(
            listenable: _authService,
            builder: (context, _) => _authService.currentUser == null
                ? LoginScreen(authService: _authService)
                : MainScreen(authService: _authService),
          );
        },
      ),
    );
  }
}
