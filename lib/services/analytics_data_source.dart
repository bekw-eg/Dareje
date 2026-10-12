import '../models/progress_analytics.dart';
import '../models/student_profile.dart';
import 'achievement_scoring_service.dart';
import 'local_achievement_service.dart';
import 'ranking_data_source.dart';
import 'student_ranking_service.dart';

abstract class AnalyticsDataSource {
  Future<ProgressAnalyticsData> load();
}

class LocalAnalyticsDataSource implements AnalyticsDataSource {
  LocalAnalyticsDataSource({
    required this.baseProfile,
    required this.achievementService,
    required this.rankingDataSource,
  });

  final StudentProfile baseProfile;
  final LocalAchievementService achievementService;
  final RankingDataSource rankingDataSource;
  final _scoring = AchievementScoringService();
  final _ranking = StudentRankingService();

  @override
  Future<ProgressAnalyticsData> load() async {
    final snapshot = await achievementService.loadSnapshot();
    final profile = _scoring.calculate(
      baseProfile: baseProfile,
      achievements: snapshot.achievements,
    );
    int? position;
    var rankingUnavailable = false;
    try {
      final profiles = await rankingDataSource.loadProfiles();
      // Используем тот же снимок своего профиля, что и в аналитике.
      final entries = _ranking.rank([
        for (final student in profiles)
          student.user.login == profile.user.login ? profile : student,
      ]);
      for (final entry in entries) {
        if (entry.profile.user.login == profile.user.login)
          position = entry.position;
      }
    } catch (_) {
      // Неполный рейтинг не превращаем в ложную позицию.
      rankingUnavailable = true;
    }
    return ProgressAnalyticsData(
      profile: profile,
      achievements: snapshot.achievements,
      history: snapshot.history,
      rankingPosition: position,
      rankingUnavailable: rankingUnavailable,
    );
  }
}
