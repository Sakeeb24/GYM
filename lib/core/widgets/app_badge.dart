// lib/core/widgets/app_badge.dart
// Athletic Status & Performance Badge
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

enum BadgeVariant { status, neutral, outline }

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final BadgeVariant variant;
  final Widget? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.variant = BadgeVariant.status,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? _defaultColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withAlpha(28),
        borderRadius: BorderRadius.circular(AppRadii.xs),
        border: Border.all(color: bg.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.labelAthletic.copyWith(
              color: bg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Color get _defaultColor => AppColors.statusOpen;
}
