// lib/core/theme/app_shadows.dart
// Clean, subtle tonal elevations for LiftFlow
import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x3D000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // Subtle tonal accent highlights (clean & minimal)
  static const List<BoxShadow> cyanGlow = [
    BoxShadow(color: Color(0x1A00D2FF), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> flameGlow = [
    BoxShadow(color: Color(0x1AFF5722), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> goldGlow = [
    BoxShadow(color: Color(0x1AFFB229), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> cardElevation = [
    BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 1)),
  ];
}
