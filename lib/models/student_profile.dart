import 'local_user.dart';
import 'student_indicator.dart';

class StudentProfile {
  StudentProfile({
    required this.user,
    this.university,
    this.specialty,
    this.course,
    this.achievementCount = 0,
    required List<StudentIndicator> indicators,
  }) : indicators = List.unmodifiable(indicators);

  // Используем существующий аккаунт, не создавая второй способ его хранения.
  final LocalUser user;
  final String? university;
  final String? specialty;
  final int? course;
  final int achievementCount;
  final List<StudentIndicator> indicators;

  String get name => '${user.firstName} ${user.lastName}'.trim();
  String get email => user.email;

  int get totalScore => indicators.isEmpty
      ? 0
      : (indicators.fold<int>(0, (sum, item) => sum + item.value) /
                indicators.length)
            .round();

  // Базовые значения: каждое начисление рассчитывается заново от них.
  factory StudentProfile.initial(LocalUser user) => StudentProfile(
    user: user,
    indicators: [
      StudentIndicator(
        type: StudentIndicatorType.academic,
        name: 'Оқу',
        value: 60,
      ),
      StudentIndicator(
        type: StudentIndicatorType.programming,
        name: 'Бағдарламалау',
        value: 68,
      ),
      StudentIndicator(
        type: StudentIndicatorType.projects,
        name: 'Жобалар',
        value: 55,
      ),
      StudentIndicator(
        type: StudentIndicatorType.teamwork,
        name: 'Топтық жұмыс',
        value: 41,
      ),
      StudentIndicator(
        type: StudentIndicatorType.sport,
        name: 'Спорт',
        value: 35,
      ),
      StudentIndicator(
        type: StudentIndicatorType.volunteering,
        name: 'Еріктілік',
        value: 30,
      ),
    ],
  );
}
