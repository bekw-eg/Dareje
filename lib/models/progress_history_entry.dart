import 'student_indicator.dart';

class ProgressHistoryEntry {
  ProgressHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.previousTotalScore,
    required this.newTotalScore,
    required Map<StudentIndicatorType, int> indicatorChanges,
    this.achievementId,
  }) : indicatorChanges = Map.unmodifiable(indicatorChanges);

  final String id;
  final DateTime timestamp;
  final int previousTotalScore;
  final int newTotalScore;
  final Map<StudentIndicatorType, int> indicatorChanges;
  final String? achievementId;

  int get totalScoreChange => newTotalScore - previousTotalScore;

  factory ProgressHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ProgressHistoryEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
        previousTotalScore: json['previousTotalScore'] as int,
        newTotalScore: json['newTotalScore'] as int,
        achievementId: json['achievementId'] as String?,
        indicatorChanges: {
          for (final item
              in (json['indicatorChanges'] as Map<String, dynamic>).entries)
            StudentIndicatorType.values.byName(item.key): item.value as int,
        },
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'previousTotalScore': previousTotalScore,
    'newTotalScore': newTotalScore,
    'indicatorChanges': {
      for (final item in indicatorChanges.entries) item.key.name: item.value,
    },
    if (achievementId != null) 'achievementId': achievementId,
  };
}
