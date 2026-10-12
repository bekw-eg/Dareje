import 'package:flutter_test/flutter_test.dart';
import 'package:student_achievements/models/achievement.dart';
import 'package:student_achievements/models/local_user.dart';
import 'package:student_achievements/models/student_indicator.dart';
import 'package:student_achievements/models/student_profile.dart';
import 'package:student_achievements/services/achievement_scoring_service.dart';

void main() {
  const user = LocalUser(
    login: 'student',
    firstName: 'Әли',
    lastName: 'Ермек',
    email: 'ali@example.kz',
    passwordHash: '',
    salt: '',
  );
  final service = AchievementScoringService();
  final baseProfile = StudentProfile.initial(user);

  Achievement achievement(String category) => Achievement(
    title: category,
    description: 'Сипаттама',
    category: category,
    date: DateTime(2026, 10, 10),
  );

  List<int> values(StudentProfile profile) =>
      profile.indicators.map((indicator) => indicator.value).toList();

  test('Empty achievements keep the existing baseline and total', () {
    final profile = service.calculate(
      baseProfile: baseProfile,
      achievements: [],
    );
    expect(values(profile), [60, 68, 55, 41, 35, 30]);
    expect(profile.totalScore, 48);
    expect(profile.achievementCount, 0);
  });

  final categoryValues = {
    'Academic': [70, 68, 55, 43, 35, 30],
    'Programming': [60, 78, 59, 41, 35, 30],
    'Projects': [60, 72, 65, 44, 35, 30],
    'Sport': [60, 68, 55, 44, 45, 30],
    'Volunteering': [60, 68, 55, 46, 35, 40],
    'Other': [60, 68, 55, 43, 35, 30],
  };
  for (final entry in categoryValues.entries) {
    test('${entry.key} affects only the specified indicators', () {
      final profile = service.calculate(
        baseProfile: baseProfile,
        achievements: [achievement(entry.key)],
      );
      expect(values(profile), entry.value);
      expect(profile.achievementCount, 1);
    });
  }

  test('Multiple achievements sum bonuses and round the shared total', () {
    final profile = service.calculate(
      baseProfile: baseProfile,
      achievements: [
        achievement('Programming'),
        achievement('Projects'),
        achievement('Volunteering'),
      ],
    );
    expect(values(profile), [60, 82, 69, 49, 35, 40]);
    expect(profile.totalScore, 56);
    expect(profile.achievementCount, 3);
  });

  test('Values remain in 0–100 and total uses capped values', () {
    final highBase = StudentProfile(
      user: user,
      indicators: [
        for (final type in StudentIndicatorType.values)
          StudentIndicator(type: type, name: type.name, value: 95),
      ],
    );
    final profile = service.calculate(
      baseProfile: highBase,
      achievements: [
        for (final category in Achievement.categories) achievement(category),
      ],
    );
    expect(values(profile), List.filled(6, 100));
    expect(profile.totalScore, 100);
    final zeroBase = StudentProfile(
      user: user,
      indicators: [
        StudentIndicator(
          type: StudentIndicatorType.programming,
          name: 'Бағдарламалау',
          value: 0,
        ),
      ],
    );
    expect(values(service.calculate(baseProfile: zeroBase, achievements: [])), [
      0,
    ]);
  });

  test(
    'Recalculation leaves baseline unchanged and never stacks old bonuses',
    () {
      final achievements = [achievement('Programming')];
      final first = service.calculate(
        baseProfile: baseProfile,
        achievements: achievements,
      );
      final repeated = service.calculate(
        baseProfile: baseProfile,
        achievements: achievements,
      );
      expect(values(first), [60, 78, 59, 41, 35, 30]);
      expect(values(repeated), values(first));
      expect(repeated.totalScore, 51);
      expect(values(baseProfile), [60, 68, 55, 41, 35, 30]);
      expect(
        values(service.calculate(baseProfile: baseProfile, achievements: [])),
        values(baseProfile),
      );
    },
  );

  test('Unknown saved categories do not change indicators', () {
    expect(
      values(
        service.calculate(
          baseProfile: baseProfile,
          achievements: [achievement('Unknown')],
        ),
      ),
      values(baseProfile),
    );
  });
}
