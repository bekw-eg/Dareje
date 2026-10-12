import 'impact_scenario.dart';
import 'student_indicator.dart';
import 'student_profile.dart';

enum SimulationRankingState {
  available,
  noPeers,
  unavailable,
  empty,
  studentMissing,
}

class MetricImpact {
  const MetricImpact({
    required this.before,
    required this.after,
    required this.potentialDelta,
  });
  final StudentIndicator before;
  final StudentIndicator after;
  final int potentialDelta;
  int get delta => after.value - before.value;
  bool get limited => delta < potentialDelta;

  String get explanation {
    if (potentialDelta == 0) return 'Бұл санат осы дағдыға балл қоспайды.';
    if (limited) {
      return 'Санат ережесі: +$potentialDelta. 100 шегіне байланысты нақты өсім: +$delta.';
    }
    return 'Санат ережесі бойынша +$delta балл қосылады.';
  }
}

class SimulationResult {
  SimulationResult({
    required this.scenario,
    required this.beforeProfile,
    required this.afterProfile,
    required List<MetricImpact> impacts,
    required this.rankingState,
    this.currentRank,
    this.predictedRank,
  }) : impacts = List.unmodifiable(impacts);

  final ImpactScenario scenario;
  final StudentProfile beforeProfile;
  final StudentProfile afterProfile;
  final List<MetricImpact> impacts;
  final SimulationRankingState rankingState;
  final int? currentRank;
  final int? predictedRank;
  List<StudentIndicator> get beforeMetrics => beforeProfile.indicators;
  List<StudentIndicator> get afterMetrics => afterProfile.indicators;
  Map<StudentIndicatorType, int> get metricDeltas => Map.unmodifiable({
    for (final impact in impacts) impact.before.type: impact.delta,
  });
  int get beforeOverallScore => beforeProfile.totalScore;
  int get afterOverallScore => afterProfile.totalScore;
  int get overallDelta => afterOverallScore - beforeOverallScore;
  int? get rankImprovement => currentRank == null || predictedRank == null
      ? null
      : currentRank! - predictedRank!;

  String get rankingExplanation => switch (rankingState) {
    SimulationRankingState.available =>
      rankImprovement! > 0
          ? '$rankImprovement орынға жоғарылай аласыз. Басқа студенттердің балдары өзгермейді.'
          : 'Орын өзгермейді. Бірдей балл алған студенттер бір орынды бөліседі.',
    SimulationRankingState.noPeers =>
      'Әзірге басқа студенттер жоқ. #1 — жалғыз жергілікті аккаунттың орны.',
    SimulationRankingState.unavailable =>
      'Рейтинг деректері оқылмады. Болжам үшін қайта есептеп көріңіз.',
    SimulationRankingState.empty =>
      'Рейтингте студенттер жоқ. Орынды болжауға дерек жеткіліксіз.',
    SimulationRankingState.studentMissing =>
      'Қазіргі аккаунт рейтингте табылмады. Орынды болжау мүмкін емес.',
  };
}

// Тек оқылған ағымдағы деректер; хранилищеге жазу әдістері жоқ.
class ImpactSimulationData {
  ImpactSimulationData({
    required this.profile,
    List<StudentProfile>? rankingProfiles,
  }) : rankingProfiles = rankingProfiles == null
           ? null
           : List.unmodifiable(rankingProfiles);
  final StudentProfile profile;
  final List<StudentProfile>? rankingProfiles;
}
