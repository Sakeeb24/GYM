// lib/core/theme/app_shadows.dart
import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  // Athletic Glowing Highlights
  static const List<BoxShadow> cyanGlow = [
    BoxShadow(color: Color(0x3300F0FF), blurRadius: 14, offset: Offset(0, 0), spreadRadius: 1),
  ];

  static const List<BoxShadow> flameGlow = [
    BoxShadow(color: Color(0x33FF5722), blurRadius: 14, offset: Offset(0, 0), spreadRadius: 1),
  ];

  static const List<BoxShadow> goldGlow = [
    BoxShadow(color: Color(0x33FFD700), blurRadius: 14, offset: Offset(0, 0), spreadRadius: 1),
  ];

  static const List<BoxShadow> cardElevation = [
    BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08FFFFFF), blurRadius: 1, offset: Offset(0, 0)),
  ];
}
