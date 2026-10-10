import '../models/local_user.dart';
import '../models/student_profile.dart';
import 'achievement_scoring_service.dart';
import 'local_achievement_service.dart';
import 'local_auth_service.dart';

abstract class RankingDataSource {
  Future<List<StudentProfile>> loadProfiles();
}

// Только настоящие аккаунты текущего устройства / браузера, не общий рейтинг.
class LocalRankingDataSource implements RankingDataSource {
  LocalRankingDataSource({
    required this.authService,
    LocalAchievementService Function(String login)? achievementServiceFor,
  }) : _achievementServiceFor =
           achievementServiceFor ??
           ((login) => LocalAchievementService(login: login));

  final LocalAuthService authService;
  final LocalAchievementService Function(String login) _achievementServiceFor;
  final _scoringService = AchievementScoringService();

  @override
  Future<List<StudentProfile>> loadProfiles() => Future.wait([
    for (final user in authService.registeredUsers) _loadProfile(user),
  ]);

  Future<StudentProfile> _loadProfile(LocalUser user) async {
    final achievements = await _achievementServiceFor(user.login).load();
    // Всегда считаем от базы: повторная загрузка не накапливает бонусы.
    // Ошибка любого аккаунта передаётся UI, чтобы не показывать ложные места.
    return _scoringService.calculate(
      baseProfile: StudentProfile.initial(user),
      achievements: achievements,
    );
  }
}
