// lib/core/theme/app_colors.dart
// LiftFlow Athletic Design System — High-performance fitness & gym visual tokens
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme (Gym / Fitness Foundation)
  static const dCanvas = Color(0xFF090A0D);         // Deep Carbon Obsidian
  static const dSurface = Color(0xFF11141A);        // Gunmetal Iron
  static const dSurfaceAlt = Color(0xFF181C24);     // Brushed Titanium
  static const dSurfaceElevated = Color(0xFF1E232B); // Raised athletic tile
  static const dBorder = Color(0x3394A3B8);         // Steel contour border
  static const dTextPrimary = Color(0xFFF8FAFC);    // High-visibility white
  static const dTextSecondary = Color(0xFF94A3B8);  // Slate graphite
  static const dTextTertiary = Color(0xFF64748B);   // Muted iron

  // Light Theme (Clean Crisp Gym Floor)
  static const lCanvas = Color(0xFFF1F5F9);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceAlt = Color(0xFFE2E8F0);
  static const lBorder = Color(0xFFCBD5E1);
  static const lTextPrimary = Color(0xFF0F172A);
  static const lTextSecondary = Color(0xFF475569);
  static const lTextTertiary = Color(0xFF94A3B8);

  // Performance Brand Accents
  static const brand = Color(0xFF00F0FF);          // Electric Cyan (High Voltage)
  static const brandDark = Color(0xFF0284C7);      // Sky Blue Deep
  static const brandContainer = Color(0xFF0C4A6E);  // Deep Cyan Hue
  static const brandGlow = Color(0x6600F0FF);      // Glow shadow

  // Training & Streak Progression
  static const flameStreak = Color(0xFFFF5722);    // Fire Orange (Athletic Streaks)
  static const flameGlow = Color(0x66FF5722);
  static const goldMedal = Color(0xFFFFD700);      // Personal Record Gold

  // Semantic Status Badges
  static const success = Color(0xFF10B981);        // Electric Emerald (Active / Granted)
  static const warning = Color(0xFFF59E0B);        // Amber Warning (Expiring)
  static const error = Color(0xFFEF4444);          // High-alert Crimson (Denied / Red List)
  static const errorContainer = Color(0x33EF4444); // Crimson Tint

  static const statusActive = Color(0xFF10B981);
  static const statusExpiring = Color(0xFFF59E0B);
  static const statusPaused = Color(0xFF60A5FA);
  static const statusExpired = Color(0xFFEF4444);
  static const statusCanceled = Color(0xFF64748B);
  static const statusOpen = Color(0xFFFF5722);
  static const statusResolved = Color(0xFF10B981);
}
