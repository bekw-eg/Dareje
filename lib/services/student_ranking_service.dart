import '../models/student_profile.dart';
import '../models/student_ranking_entry.dart';

class StudentRankingService {
  List<StudentRankingEntry> rank(List<StudentProfile> profiles) {
    final sorted = [...profiles];
    sorted.sort((a, b) {
      final scoreOrder = b.totalScore.compareTo(a.totalScore);
      // Уникальный логин сохраняет порядок при равных баллах между загрузками.
      return scoreOrder != 0
          ? scoreOrder
          : a.user.login.compareTo(b.user.login);
    });

    var position = 0;
    final entries = <StudentRankingEntry>[];
    for (var index = 0; index < sorted.length; index++) {
      if (index == 0 ||
          sorted[index].totalScore != sorted[index - 1].totalScore) {
        position = index + 1;
      }
      entries.add(
        StudentRankingEntry(profile: sorted[index], position: position),
      );
    }
    // Здесь только расстановка мест: очки уже рассчитаны в StudentProfile.
    return List.unmodifiable(entries);
  }
}
