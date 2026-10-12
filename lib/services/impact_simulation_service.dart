import '../models/impact_scenario.dart';
import '../models/simulation_result.dart';
import '../models/student_profile.dart';
import 'achievement_scoring_service.dart';
import 'student_ranking_service.dart';

class ImpactSimulationService {
  final _scoring = AchievementScoringService();
  final _ranking = StudentRankingService();

  // Чистый расчёт: без достижений, случайных ID, часов и хранилища.
  SimulationResult simulate({
    required StudentProfile profile,
    required ImpactScenario scenario,
    List<StudentProfile>? rankingProfiles,
  }) {
    final afterIndicators = _scoring.calculateCategoryIndicators(
      baseIndicators: profile.indicators,
      category: scenario.category,
    );
    final after = StudentProfile(
      user: profile.user,
      university: profile.university,
      specialty: profile.specialty,
      course: profile.course,
      achievementCount: profile.achievementCount,
      indicators: afterIndicators,
    );
    final bonuses = _scoring.bonusesForCategory(scenario.category);
    int? currentRank;
    int? predictedRank;
    var state = SimulationRankingState.unavailable;
    if (rankingProfiles != null) {
      final logins = rankingProfiles
          .map((student) => student.user.login)
          .toSet();
      if (rankingProfiles.isEmpty) {
        state = SimulationRankingState.empty;
      } else if (logins.length != rankingProfiles.length) {
        // Повторяющийся аккаунт не должен создавать ложные места.
        state = SimulationRankingState.unavailable;
      } else if (!logins.contains(profile.user.login)) {
        state = SimulationRankingState.studentMissing;
      } else {
        state = rankingProfiles.length == 1
            ? SimulationRankingState.noPeers
            : SimulationRankingState.available;
        int positionFor(StudentProfile current) => _ranking
            .rank([
              for (final student in rankingProfiles)
                student.user.login == profile.user.login ? current : student,
            ])
            .firstWhere(
              (entry) => entry.profile.user.login == profile.user.login,
            )
            .position;
        // Один снимок своего профиля в обоих расчётах; остальные неизменны.
        currentRank = positionFor(profile);
        predictedRank = positionFor(after);
      }
    }
    return SimulationResult(
      scenario: scenario,
      beforeProfile: profile,
      afterProfile: after,
      impacts: [
        for (var i = 0; i < profile.indicators.length; i++)
          MetricImpact(
            before: profile.indicators[i],
            after: afterIndicators[i],
            potentialDelta: bonuses[profile.indicators[i].type] ?? 0,
          ),
      ],
      rankingState: state,
      currentRank: currentRank,
      predictedRank: predictedRank,
    );
  }
}
