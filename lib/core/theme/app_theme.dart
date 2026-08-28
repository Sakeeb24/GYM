// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radii.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light(BuildContext ctx) => _build(Brightness.light);
  static ThemeData dark(BuildContext ctx) => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.dSurface : AppColors.lSurface;
    final surfaceAlt = isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt;
    final onSurface = isDark ? AppColors.dTextPrimary : AppColors.lTextPrimary;
    final onSurfaceVariant = isDark ? AppColors.dTextSecondary : AppColors.lTextSecondary;

    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandContainer,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      error: AppColors.error,
      errorContainer: AppColors.errorContainer,
      outline: isDark ? AppColors.dBorder : AppColors.lBorder,
      outlineVariant: isDark ? AppColors.dBorder : AppColors.lBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: isDark ? AppColors.dCanvas : AppColors.lCanvas,
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelSmall: AppTypography.labelSmall,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: isDark ? AppColors.dBorder : AppColors.lBorder,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r16,
          side: BorderSide(color: isDark ? AppColors.dBorder : AppColors.lBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(borderRadius: AppRadii.r8, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.r8,
          borderSide: BorderSide(color: AppColors.brand, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: onSurfaceVariant, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.r8),
          textStyle: AppTypography.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          side: BorderSide(color: isDark ? AppColors.dBorder : AppColors.lBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.r8),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.dBorder : AppColors.lBorder, thickness: 1,
      ),
    );
  }
}
