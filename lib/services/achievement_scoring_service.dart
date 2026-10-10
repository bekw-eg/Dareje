import '../models/achievement.dart';
import '../models/student_indicator.dart';
import '../models/student_profile.dart';

class AchievementScoringService {
  static const _categoryBonuses = {
    'Academic': {
      StudentIndicatorType.academic: 10,
      StudentIndicatorType.teamwork: 2,
    },
    'Programming': {
      StudentIndicatorType.programming: 10,
      StudentIndicatorType.projects: 4,
    },
    'Projects': {
      StudentIndicatorType.projects: 10,
      StudentIndicatorType.programming: 4,
      StudentIndicatorType.teamwork: 3,
    },
    'Sport': {StudentIndicatorType.sport: 10, StudentIndicatorType.teamwork: 3},
    'Volunteering': {
      StudentIndicatorType.volunteering: 10,
      StudentIndicatorType.teamwork: 5,
    },
    'Other': {StudentIndicatorType.teamwork: 2},
  };

  StudentProfile calculate({
    required StudentProfile baseProfile,
    required List<Achievement> achievements,
  }) {
    final bonuses = <StudentIndicatorType, int>{};
    // Каждая сохранённая запись учитывается один раз за расчёт.
    for (final achievement in achievements) {
      final influence = _categoryBonuses[achievement.category];
      if (influence == null) continue;
      for (final bonus in influence.entries) {
        bonuses[bonus.key] = (bonuses[bonus.key] ?? 0) + bonus.value;
      }
    }

    // Не изменяем базовый профиль и не сохраняем накопленные баллы.
    // Общий балл вычисляет существующий StudentProfile.totalScore.
    return StudentProfile(
      user: baseProfile.user,
      university: baseProfile.university,
      specialty: baseProfile.specialty,
      course: baseProfile.course,
      achievementCount: achievements.length,
      indicators: [
        for (final indicator in baseProfile.indicators)
          StudentIndicator(
            type: indicator.type,
            name: indicator.name,
            value: (indicator.value + (bonuses[indicator.type] ?? 0)).clamp(
              0,
              100,
            ),
          ),
      ],
    );
  }
}
