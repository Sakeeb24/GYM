// lib/core/widgets/app_badge.dart
// Athletic Status, Streak & Performance Badge
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

enum BadgeVariant { status, neutral, outline, solid }

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final BadgeVariant variant;
  final Widget? icon;
  final bool showDot;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.variant = BadgeVariant.status,
    this.icon,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.brand;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: variant == BadgeVariant.solid ? bg : bg.withAlpha(25),
        borderRadius: BorderRadius.circular(AppRadii.xs),
        border: Border.all(
          color: variant == BadgeVariant.solid ? Colors.transparent : bg.withAlpha(80),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: variant == BadgeVariant.solid ? Colors.black : bg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.labelAthletic.copyWith(
              color: variant == BadgeVariant.solid ? Colors.black : bg,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}
