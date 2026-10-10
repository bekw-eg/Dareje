import 'package:flutter/material.dart';
import '../models/student_profile.dart';
import '../services/local_auth_service.dart';
import '../services/local_achievement_service.dart';
import '../services/achievement_scoring_service.dart';
import '../services/ranking_data_source.dart';
import 'achievements_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.authService,
    this.achievementService,
    this.rankingDataSource,
  });

  final LocalAuthService authService;
  final LocalAchievementService? achievementService;
  final RankingDataSource? rankingDataSource;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isSigningOut = false;
  late final _achievementService =
      widget.achievementService ??
      LocalAchievementService(login: widget.authService.currentUser!.login);
  late final _baseProfile = StudentProfile.initial(
    widget.authService.currentUser!,
  );
  final _scoringService = AchievementScoringService();
  late Future<StudentProfile> _loadingProfile;
  int _dataRevision = 0;
  late final _rankingDataSource =
      widget.rankingDataSource ??
      LocalRankingDataSource(
        authService: widget.authService,
        achievementServiceFor: (login) => login == _baseProfile.user.login
            ? _achievementService
            : LocalAchievementService(login: login),
      );

  static const _titles = ['Басты бет', 'Жетістіктер', 'Рейтинг', 'Профиль'];

  @override
  void initState() {
    super.initState();
    _loadingProfile = _loadProfile();
  }

  Future<StudentProfile> _loadProfile() async {
    final achievements = await _achievementService.load();
    return _scoringService.calculate(
      baseProfile: _baseProfile,
      achievements: achievements,
    );
  }

  void _reloadProfile() {
    setState(() {
      _loadingProfile = _loadProfile();
      _dataRevision++;
    });
  }

  Widget _buildBody() {
    return FutureBuilder<StudentProfile>(
      future: _loadingProfile,
      builder: (context, snapshot) {
        // Список и рейтинг доступны даже при ошибке загрузки профиля.
        if (_selectedIndex == 1) {
          return AchievementsScreen(
            service: _achievementService,
            onSaved: _reloadProfile,
          );
        }
        if (_selectedIndex == 2) {
          return RankingScreen(
            dataSource: _rankingDataSource,
            currentLogin: _baseProfile.user.login,
            dataRevision: _dataRevision,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Профильді жүктеу мүмкін болмады.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _reloadProfile,
                    child: const Text('Қайта көру'),
                  ),
                ],
              ),
            ),
          );
        }
        final profile = snapshot.data!;
        return _selectedIndex == 0
            ? HomeScreen(
                firstName: profile.user.firstName,
                totalScore: profile.totalScore,
                onAddAchievement: () => setState(() => _selectedIndex = 1),
              )
            : ProfileScreen(profile: profile);
      },
    );
  }

  Future<void> _logout() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await widget.authService.logout();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Шығу сақталмады. Қайта көріңіз')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          TextButton.icon(
            onPressed: _isSigningOut ? null : _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Шығу'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Басты бет',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Жетістіктер',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined),
            activeIcon: Icon(Icons.leaderboard),
            label: 'Рейтинг',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
