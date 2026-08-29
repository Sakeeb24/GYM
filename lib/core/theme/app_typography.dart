// lib/core/theme/app_typography.dart
// Athletic Typography for LiftFlow — Bold, High-Energy & Legible
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _font(double size, FontWeight weight, {double height = 1.3, double? letterSpacing}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing ?? 0,
      );

  // Large athletic display headers
  static final displayLarge = _font(32, FontWeight.w800, height: 1.15, letterSpacing: -0.8);
  static final displayMedium = _font(26, FontWeight.w800, height: 1.2, letterSpacing: -0.5);
  static final displaySmall = _font(22, FontWeight.w700, height: 1.25, letterSpacing: -0.3);

  // Athletic numeric KPI metrics (e.g. 1,248 / 87% / ₹84,500)
  static final metricLarge = _font(36, FontWeight.w900, height: 1.1, letterSpacing: -1.0);
  static final metricMedium = _font(28, FontWeight.w800, height: 1.15, letterSpacing: -0.6);
  static final metricSmall = _font(20, FontWeight.w800, height: 1.2, letterSpacing: -0.3);

  // Headings
  static final headlineLarge = _font(20, FontWeight.w700, height: 1.3, letterSpacing: -0.2);
  static final headlineMedium = _font(18, FontWeight.w700, height: 1.35, letterSpacing: -0.1);
  static final headlineSmall = _font(16, FontWeight.w700, height: 1.4);
  static final titleMedium = _font(14, FontWeight.w600, height: 1.4);

  // Body text
  static final bodyLarge = _font(16, FontWeight.w400, height: 1.5);
  static final bodyMedium = _font(14, FontWeight.w400, height: 1.45);
  static final bodySmall = _font(12, FontWeight.w400, height: 1.4);

  // Athletic tracked labels & badges
  static final labelLarge = _font(13, FontWeight.w700, height: 1.2, letterSpacing: 0.75);
  static final labelSmall = _font(10, FontWeight.w800, height: 1.1, letterSpacing: 1.0);
  static final labelAthletic = _font(11, FontWeight.w800, height: 1.2, letterSpacing: 1.2);
}
