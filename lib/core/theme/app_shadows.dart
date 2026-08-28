// lib/core/theme/app_shadows.dart
import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0C000000), blurRadius: 24, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0C000000), blurRadius: 32, offset: Offset(0, 16)),
  ];
}
