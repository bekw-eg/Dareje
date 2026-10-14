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
  }) => recordChange(
    before: before,
    after: [...before, achievement],
    achievementId: achievement.id!,
    operation: AchievementChange.addition,
    timestamp: timestamp,
  );

  ProgressHistoryEntry recordChange({
    required List<Achievement> before,
    required List<Achievement> after,
    required String achievementId,
    required AchievementChange operation,
    required DateTime timestamp,
  }) {
    final base = StudentProfile.initialIndicators();
    final previous = _scoring.calculateIndicators(
      baseIndicators: base,
      achievements: before,
    );
    final next = _scoring.calculateIndicators(
      baseIndicators: base,
      achievements: after,
    );
    return ProgressHistoryEntry(
      id: operation == AchievementChange.addition
          ? 'achievement:$achievementId'
          : '${operation.name}:${Achievement.createId()}',
      achievementId: achievementId,
      operation: operation,
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
