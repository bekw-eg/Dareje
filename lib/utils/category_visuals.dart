import 'package:flutter/material.dart';
import '../models/student_indicator.dart';
import 'app_colors.dart';

abstract final class CategoryVisuals {
  static String label(String category) => switch (category) {
    'Academic' => 'Оқу',
    'Programming' => 'Бағдарламалау',
    'Projects' => 'Жобалар',
    'Sport' => 'Спорт',
    'Volunteering' => 'Еріктілік',
    _ => 'Басқа',
  };
  static IconData icon(String category) => switch (category) {
    'Academic' => Icons.school_outlined,
    'Programming' => Icons.code_rounded,
    'Projects' => Icons.layers_outlined,
    'Sport' => Icons.sports_score_outlined,
    'Volunteering' => Icons.volunteer_activism_outlined,
    _ => Icons.auto_awesome_outlined,
  };
  static Color color(String category) => switch (category) {
    'Academic' => AppColors.blue,
    'Programming' => AppColors.violet,
    'Projects' => AppColors.teal,
    'Sport' => AppColors.amber,
    'Volunteering' => AppColors.rose,
    _ => AppColors.muted,
  };
  static String category(StudentIndicatorType type) => switch (type) {
    StudentIndicatorType.academic => 'Academic',
    StudentIndicatorType.programming => 'Programming',
    StudentIndicatorType.projects => 'Projects',
    StudentIndicatorType.sport => 'Sport',
    StudentIndicatorType.volunteering => 'Volunteering',
    StudentIndicatorType.teamwork => 'Other',
  };
  static IconData skillIcon(StudentIndicatorType type) =>
      type == StudentIndicatorType.teamwork
      ? Icons.groups_outlined
      : icon(category(type));
}
