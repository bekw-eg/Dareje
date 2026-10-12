import '../models/simulation_result.dart';
import '../models/student_profile.dart';
import 'achievement_scoring_service.dart';
import 'local_achievement_service.dart';
import 'ranking_data_source.dart';

abstract class ImpactSimulationDataSource {
  Future<ImpactSimulationData> load();
}

class LocalImpactSimulationDataSource implements ImpactSimulationDataSource {
  LocalImpactSimulationDataSource({
    required this.baseProfile,
    required this.achievementService,
    required this.rankingDataSource,
  });
  final StudentProfile baseProfile;
  final LocalAchievementService achievementService;
  final RankingDataSource rankingDataSource;
  final _scoring = AchievementScoringService();

  @override
  Future<ImpactSimulationData> load() async {
    final achievements = await achievementService.load();
    final profile = _scoring.calculate(
      baseProfile: baseProfile,
      achievements: achievements,
    );
    List<StudentProfile>? profiles;
    try {
      profiles = await rankingDataSource.loadProfiles();
    } catch (_) {
      // Ошибка чужого профиля исключает весь прогноз, но не личные показатели.
    }
    return ImpactSimulationData(profile: profile, rankingProfiles: profiles);
  }
}
