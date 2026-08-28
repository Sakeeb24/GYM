// lib/core/theme/app_radii.dart
import 'package:flutter/material.dart';

class AppRadii {
  AppRadii._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius get r8 => BorderRadius.circular(sm);
  static BorderRadius get r12 => BorderRadius.circular(md);
  static BorderRadius get r16 => BorderRadius.circular(lg);
}
