// lib/core/theme/app_colors.dart
// LiftFlow Athletic Design System — High-performance fitness & gym visual tokens
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme (Gym / Strength Foundation)
  static const dCanvas = Color(0xFF07080A);         // Obsidian Black
  static const dSurface = Color(0xFF0F1217);        // Deep Graphite Iron
  static const dSurfaceAlt = Color(0xFF161A22);     // Brushed Slate
  static const dSurfaceElevated = Color(0xFF1F2430); // Raised Athletic Tile
  static const dBorder = Color(0xFF262D3D);         // Steel Contour Border
  static const dBorderSubtle = Color(0x1FFFFFFF);   // 12% White Border
  static const dTextPrimary = Color(0xFFF8FAFC);    // High-visibility White
  static const dTextSecondary = Color(0xFF94A3B8);  // Slate Graphite
  static const dTextTertiary = Color(0xFF64748B);   // Muted Iron

  // Light Theme (Clean Crisp Gym Floor)
  static const lCanvas = Color(0xFFF8FAFC);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceAlt = Color(0xFFF1F5F9);
  static const lSurfaceElevated = Color(0xFFE2E8F0);
  static const lBorder = Color(0xFFCBD5E1);
  static const lBorderSubtle = Color(0x1F000000);
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
  static const goldGlow = Color(0x66FFD700);

  // Semantic Status Badges
  static const success = Color(0xFF10B981);        // Athletic Emerald (Active / Granted)
  static const warning = Color(0xFFF59E0B);        // Amber Warning (Expiring)
  static const error = Color(0xFFEF4444);          // High-alert Crimson (Denied / Red List)
  static const errorContainer = Color(0x33EF4444); // Crimson Tint

  // Status mapping
  static const statusActive = Color(0xFF10B981);
  static const statusExpiring = Color(0xFFF59E0B);
  static const statusPaused = Color(0xFF60A5FA);
  static const statusExpired = Color(0xFFEF4444);
  static const statusCanceled = Color(0xFF64748B);
  static const statusOpen = Color(0xFFFF5722);
  static const statusResolved = Color(0xFF10B981);
  static const statusNew = Color(0xFF00F0FF);
}
