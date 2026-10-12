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

  // Симулятор читает те же правила, не создавая настоящее достижение.
  Map<StudentIndicatorType, int> bonusesForCategory(String category) =>
      Map.unmodifiable(_categoryBonuses[category] ?? {});

  List<StudentIndicator> calculateCategoryIndicators({
    required List<StudentIndicator> baseIndicators,
    required String category,
  }) => _applyBonuses(baseIndicators, bonusesForCategory(category));

  StudentProfile calculate({
    required StudentProfile baseProfile,
    required List<Achievement> achievements,
  }) => StudentProfile(
    user: baseProfile.user,
    university: baseProfile.university,
    specialty: baseProfile.specialty,
    course: baseProfile.course,
    achievementCount: achievements.length,
    indicators: calculateIndicators(
      baseIndicators: baseProfile.indicators,
      achievements: achievements,
    ),
  );

  // Один расчёт для профиля, рейтинга и наблюдаемых изменений истории.
  List<StudentIndicator> calculateIndicators({
    required List<StudentIndicator> baseIndicators,
    required List<Achievement> achievements,
  }) {
    final bonuses = <StudentIndicatorType, int>{};
    // Каждая сохранённая запись учитывается один раз за расчёт.
    for (final achievement in achievements) {
      final influence = bonusesForCategory(achievement.category);
      for (final bonus in influence.entries) {
        bonuses[bonus.key] = (bonuses[bonus.key] ?? 0) + bonus.value;
      }
    }

    return _applyBonuses(baseIndicators, bonuses);
  }

  List<StudentIndicator> _applyBonuses(
    List<StudentIndicator> baseIndicators,
    Map<StudentIndicatorType, int> bonuses,
  ) {
    // Не изменяем базовый профиль и не сохраняем накопленные баллы.
    // Общий балл вычисляет существующий StudentProfile.totalScore.
    return [
      for (final indicator in baseIndicators)
        StudentIndicator(
          type: indicator.type,
          name: indicator.name,
          value: (indicator.value + (bonuses[indicator.type] ?? 0)).clamp(
            0,
            100,
          ),
        ),
    ];
  }
}
