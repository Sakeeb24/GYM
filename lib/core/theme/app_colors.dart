// lib/core/theme/app_colors.dart
// LiftFlow design tokens (Google Stitch foundation, Taste/Awesome principles):
// clean hierarchy, restrained palette, premium feel, 3:1+ contrast ratios.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Light theme
  static const lCanvas = Color(0xFFF6F8FB);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceAlt = Color(0xFFF0F3F7);
  static const lBorder = Color(0xFFE2E8F0);
  static const lTextPrimary = Color(0xFF0F172A);
  static const lTextSecondary = Color(0xFF64748B);
  static const lTextTertiary = Color(0xFF94A3B8);

  // Dark theme
  static const dCanvas = Color(0xFF0F1115);
  static const dSurface = Color(0xFF171921);
  static const dSurfaceAlt = Color(0xFF1F2129);
  static const dBorder = Color(0x2994A3B8);
  static const dTextPrimary = Color(0xFFE4E1ED);
  static const dTextSecondary = Color(0xFFB3AFC9);
  static const dTextTertiary = Color(0xFF89879E);

  // Brand
  static const brand = Color(0xFF0EA5E9);       // sky blue (trust + energy)
  static const brandHover = Color(0xFF0284C7);
  static const brandContainer = Color(0xFFBAE6FD);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const errorContainer = Color(0xFFFEE2E2);

  // Semantic status badges
  static const statusActive = Color(0xFF10B981);
  static const statusPaused = Color(0xFFF59E0B);
  static const statusExpired = Color(0xFFEF4444);
  static const statusCanceled = Color(0xFF6B7280);
  static const statusOpen = Color(0xFFEF4444);
  static const statusResolved = Color(0xFF10B981);
}
