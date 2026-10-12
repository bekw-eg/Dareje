import 'package:flutter/material.dart';

/// Цвет — акцент, основа интерфейса остаётся нейтральной.
abstract final class AppColors {
  static const violet = Color(0xFF6C47D9);
  static const deepViolet = Color(0xFF34216B);
  static const lavender = Color(0xFFF0EAFF);
  static const canvas = Color(0xFFF8F7FC);
  static const ink = Color(0xFF211D32);
  static const muted = Color(0xFF706A80);
  static const line = Color(0xFFE8E4EF);
  static const teal = Color(0xFF167D83);
  static const mint = Color(0xFFE3F3F0);
  static const deepTeal = Color(0xFF125C58);
  static const blue = Color(0xFF4169BE);
  static const amber = Color(0xFFA56617);
  static const rose = Color(0xFFAE4872);
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepViolet, Color(0xFF6241B8)],
  );
}
