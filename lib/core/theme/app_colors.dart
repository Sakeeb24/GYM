// lib/core/theme/app_colors.dart
// LiftFlow Clean Modern Fitness Design Tokens (Apex Precision)
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme (Restrained Charcoal Canvas & Surfaces)
  static const dCanvas = Color(0xFF111316);         // Clean Dark Charcoal
  static const dSurface = Color(0xFF1A1D21);        // Neutral Slate Surface
  static const dSurfaceAlt = Color(0xFF22262B);     // Secondary Surface
  static const dSurfaceElevated = Color(0xFF2A2F35); // Input & Elevated Fill
  static const dBorder = Color(0xFF2E333A);         // Clean Subtle Border (1px)
  static const dBorderSubtle = Color(0x1AFFFFFF);   // 10% White Border
  static const dTextPrimary = Color(0xFFE2E2E6);    // Crisp High-contrast Text
  static const dTextSecondary = Color(0xFF859399);  // Muted Label / Body Gray
  static const dTextTertiary = Color(0xFF5E6A70);   // Subtle Gray

  // Light Theme (Clean Crisp Minimalist)
  static const lCanvas = Color(0xFFF8FAFC);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceAlt = Color(0xFFF1F5F9);
  static const lSurfaceElevated = Color(0xFFE2E8F0);
  static const lBorder = Color(0xFFE2E8F0);
  static const lBorderSubtle = Color(0x1F000000);
  static const lTextPrimary = Color(0xFF0F172A);
  static const lTextSecondary = Color(0xFF475569);
  static const lTextTertiary = Color(0xFF94A3B8);

  // Single Energetic Accent (Used sparingly for Primary Actions, Active Nav, Progress)
  static const brand = Color(0xFF00D2FF);          // Energetic Action Cyan
  static const brandDark = Color(0xFF0088AA);      // Contrast Cyan for Light Mode
  static const brandContainer = Color(0xFF003543);  // Muted Cyan Tint
  static const brandGlow = Color(0x3300D2FF);

  // Training, Streaks & Status
  static const flameStreak = Color(0xFFFF5722);    // Fire Orange for Streaks
  static const flameGlow = Color(0x33FF5722);
  static const goldMedal = Color(0xFFFFB229);      // PR Gold
  static const goldGlow = Color(0x33FFB229);

  // Semantic Status Badges
  static const success = Color(0xFF10B981);        // Clean Emerald Green
  static const warning = Color(0xFFF59E0B);        // Clean Amber
  static const error = Color(0xFFEF4444);          // Clean Coral Red
  static const errorContainer = Color(0x26EF4444); // 15% Red Tint

  // Status mapping
  static const statusActive = Color(0xFF10B981);
  static const statusExpiring = Color(0xFFF59E0B);
  static const statusPaused = Color(0xFF60A5FA);
  static const statusExpired = Color(0xFFEF4444);
  static const statusCanceled = Color(0xFF64748B);
  static const statusOpen = Color(0xFFFF5722);
  static const statusResolved = Color(0xFF10B981);
  static const statusNew = Color(0xFF00D2FF);
}
