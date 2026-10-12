import '../models/achievement.dart';
import '../models/progress_history_entry.dart';
import '../models/student_profile.dart';
import 'achievement_scoring_service.dart';

class ProgressHistoryService {
  final _scoring = AchievementScoringService();

  ProgressHistoryEntry recordAddition({
    required List<Achievement> before,
    required Achievement achievement,
    required DateTime timestamp,
  }) {
    final base = StudentProfile.initialIndicators();
    final previous = _scoring.calculateIndicators(
      baseIndicators: base,
      achievements: before,
    );
    final next = _scoring.calculateIndicators(
      baseIndicators: base,
      achievements: [...before, achievement],
    );
    return ProgressHistoryEntry(
      id: 'achievement:${achievement.id}',
      achievementId: achievement.id,
      timestamp: timestamp.toUtc(),
      previousTotalScore: StudentProfile.scoreFor(previous),
      newTotalScore: StudentProfile.scoreFor(next),
      indicatorChanges: {
        for (var index = 0; index < next.length; index++)
          next[index].type: next[index].value - previous[index].value,
      },
    );
  }
}
