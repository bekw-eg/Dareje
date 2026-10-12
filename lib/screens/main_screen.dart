import 'package:flutter/material.dart';
import '../models/student_profile.dart';
import '../models/achievement.dart';
import '../services/student_ranking_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/dareje_navigation.dart';
import 'add_achievement_screen.dart';
import '../services/local_auth_service.dart';
import '../services/local_achievement_service.dart';
import '../services/achievement_scoring_service.dart';
import '../services/ranking_data_source.dart';
import '../services/analytics_data_source.dart';
import '../services/impact_simulation_data_source.dart';
import 'achievements_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';
import 'progress_analytics_screen.dart';
import 'impact_simulator_screen.dart';

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
  late Future<int?> _loadingPosition;
  List<Achievement> _achievements = [];
  int _dataRevision = 0;
  late final _rankingDataSource =
      widget.rankingDataSource ??
      LocalRankingDataSource(
        authService: widget.authService,
        achievementServiceFor: (login) => login == _baseProfile.user.login
            ? _achievementService
            : LocalAchievementService(login: login),
      );

  late final _analyticsDataSource = LocalAnalyticsDataSource(
    baseProfile: _baseProfile,
    achievementService: _achievementService,
    rankingDataSource: _rankingDataSource,
  );

  late final _simulationDataSource = LocalImpactSimulationDataSource(
    baseProfile: _baseProfile,
    achievementService: _achievementService,
    rankingDataSource: _rankingDataSource,
  );

  void _openSimulator() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Ықпал симуляторы')),
          body: SafeArea(
            child: ImpactSimulatorScreen(dataSource: _simulationDataSource),
          ),
        ),
      ),
    );
  }

  static const _titles = [
    'Басты бет',
    'Жетістіктер',
    'Рейтинг',
    'Профиль',
    'Талдау',
  ];

  @override
  void initState() {
    super.initState();
    _loadingProfile = _loadProfile();
    _loadingPosition = _loadPosition();
  }

  Future<StudentProfile> _loadProfile() async {
    final achievements = await _achievementService.load();
    _achievements = achievements;
    return _scoringService.calculate(
      baseProfile: _baseProfile,
      achievements: achievements,
    );
  }

  Future<int?> _loadPosition() async {
    try {
      final profiles = await _rankingDataSource.loadProfiles();
      if (profiles.map((p) => p.user.login).toSet().length != profiles.length)
        return null;
      final entries = StudentRankingService().rank(profiles);
      for (final entry in entries) {
        if (entry.profile.user.login == _baseProfile.user.login)
          return entry.position;
      }
    } catch (_) {
      // Сбой рейтинга не скрывает достоверный личный профиль.
    }
    return null;
  }

  Future<void> _addAchievement() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddAchievementScreen(service: _achievementService),
      ),
    );
    if (saved == true && mounted) _reloadProfile();
  }

  void _selectTab(int index) {
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }

  void _reloadProfile() {
    setState(() {
      _loadingProfile = _loadProfile();
      _loadingPosition = _loadPosition();
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
        if (_selectedIndex == 4) {
          return ProgressAnalyticsScreen(
            dataSource: _analyticsDataSource,
            dataRevision: _dataRevision,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppSkeleton(label: 'Профиль жүктелуде');
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
            ? FutureBuilder<int?>(
                future: _loadingPosition,
                builder: (context, position) => HomeScreen(
                  profile: profile,
                  achievements: _achievements,
                  rankingPosition:
                      position.connectionState == ConnectionState.done
                      ? position.data
                      : null,
                  onAddAchievement: _addAchievement,
                  onOpenAchievements: () => _selectTab(1),
                  onOpenRanking: () => _selectTab(2),
                  onOpenProfile: () => _selectTab(3),
                  onOpenAnalytics: () => _selectTab(4),
                  onOpenSimulator: _openSimulator,
                ),
              )
            : ProfileScreen(
                profile: profile,
                onOpenAchievements: () => _selectTab(1),
                onOpenAnalytics: () => _selectTab(4),
              );
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
        title: Text(_selectedIndex == 0 ? 'Dáreje' : _titles[_selectedIndex]),
        actions: [
          TextButton.icon(
            onPressed: _isSigningOut ? null : _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Шығу'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AppStateSwitch(
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: _buildBody(),
          ),
        ),
      ),
      bottomNavigationBar: DarejeNavigation(
        index: _selectedIndex,
        onChanged: _selectTab,
      ),
    );
  }
}
