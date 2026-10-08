import 'local_user.dart';
import 'student_indicator.dart';

class StudentProfile {
  StudentProfile({
    required this.user,
    this.university,
    this.specialty,
    this.course,
    required List<StudentIndicator> indicators,
  }) : indicators = List.unmodifiable(indicators);

  // Используем существующий аккаунт, не создавая второй способ его хранения.
  final LocalUser user;
  final String? university;
  final String? specialty;
  final int? course;
  final List<StudentIndicator> indicators;

  String get name => '${user.firstName} ${user.lastName}'.trim();
  String get email => user.email;

  int get totalScore => indicators.isEmpty
      ? 0
      : (indicators.fold<int>(0, (sum, item) => sum + item.value) /
                indicators.length)
            .round();

  // Временные значения. Позже сюда можно передать показатели из достижений.
  factory StudentProfile.initial(LocalUser user) => StudentProfile(
    user: user,
    indicators: [
      StudentIndicator(name: 'Оқу', value: 60),
      StudentIndicator(name: 'Бағдарламалау', value: 68),
      StudentIndicator(name: 'Жобалар', value: 55),
      StudentIndicator(name: 'Топтық жұмыс', value: 41),
      StudentIndicator(name: 'Спорт', value: 35),
      StudentIndicator(name: 'Еріктілік', value: 30),
    ],
  );
}
