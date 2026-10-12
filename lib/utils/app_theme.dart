import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.violet).copyWith(
      primary: AppColors.violet,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lavender,
      onPrimaryContainer: AppColors.deepViolet,
      secondary: AppColors.teal,
      tertiary: AppColors.teal,
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outlineVariant: AppColors.line,
      surfaceContainerLow: AppColors.canvas,
    ),
    textTheme: AppTypography.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFBA3352)),
      ),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: AppTypography.textTheme.titleSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        animationDuration: AppMotion.quick,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.lavender,
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.deepViolet,
      ),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      showCheckmark: false,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(bottom: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.5,
      ),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const AppPageTransitions(),
      },
    ),
  );
}
