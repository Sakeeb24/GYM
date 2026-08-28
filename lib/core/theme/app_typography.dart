// lib/core/theme/app_typography.dart
// Plus Jakarta Sans (Stitch) — loaded via google_fonts; fallback to system.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _font(double size, FontWeight weight, {double height = 1.3, double? letterSpacing}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size, fontWeight: weight, height: height, letterSpacing: letterSpacing ?? 0,
      );

  static final displayLarge = _font(34, FontWeight.w700, height: 1.2, letterSpacing: -0.5);
  static final displayMedium = _font(28, FontWeight.w700, height: 1.2, letterSpacing: -0.25);
  static final headlineLarge = _font(20, FontWeight.w600, height: 1.3);
  static final headlineMedium = _font(18, FontWeight.w600, height: 1.35);
  static final headlineSmall = _font(16, FontWeight.w600, height: 1.4);
  static final titleMedium = _font(14, FontWeight.w600, height: 1.4);
  static final bodyLarge = _font(16, FontWeight.w400, height: 1.55);
  static final bodyMedium = _font(14, FontWeight.w400, height: 1.5);
  static final bodySmall = _font(12, FontWeight.w400, height: 1.5);
  static final labelLarge = _font(14, FontWeight.w600, height: 1.3, letterSpacing: 0.25);
  static final labelSmall = _font(11, FontWeight.w600, height: 1.2, letterSpacing: 0.5);
}
