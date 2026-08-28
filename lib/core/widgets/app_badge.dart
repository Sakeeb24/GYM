// lib/core/widgets/app_badge.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

enum BadgeVariant { status, neutral }

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final BadgeVariant variant;

  const AppBadge({super.key, required this.label, this.color, this.variant = BadgeVariant.status});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? _defaultColor;
    final fg = _foregroundFor(bg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withAlpha(16),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: fg)),
    );
  }

  Color get _defaultColor => AppColors.statusOpen;

  static Color _foregroundFor(Color bg) {
    return bg.computeLuminance() < 0.5 ? Colors.white : Colors.black87;
  }
}
