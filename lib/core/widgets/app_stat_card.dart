// lib/core/widgets/app_stat_card.dart
// Gym Performance & Athletic KPI Metric Card
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

class StatCardData {
  final String title;
  final String value;
  final String? subtitle;
  final Widget? icon;
  final Color? accentColor;
  final bool isGlowing;

  const StatCardData({
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.isGlowing = false,
  });
}

class StatCard extends StatelessWidget {
  final StatCardData data;
  final VoidCallback? onTap;

  const StatCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = data.accentColor ?? (isDark ? AppColors.brand : AppColors.brandDark);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r16,
        border: Border.all(
          color: data.isGlowing ? accent.withAlpha(80) : cs.outline,
          width: data.isGlowing ? 1.5 : 1,
        ),
        boxShadow: data.isGlowing
            ? [
                BoxShadow(
                  color: accent.withAlpha(35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : (isDark ? AppShadows.cardElevation : AppShadows.sm),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.r16,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        style: AppTypography.labelAthletic.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 10,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data.icon != null)
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.withAlpha(50), width: 1),
                        ),
                        child: IconTheme(
                          data: IconThemeData(color: accent, size: 16),
                          child: data.icon!,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  data.value,
                  style: AppTypography.metricLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                ),
                if (data.subtitle != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (data.subtitle!.contains('↑') || data.subtitle!.startsWith('+'))
                        const Icon(Icons.arrow_upward_rounded, size: 13, color: AppColors.success)
                      else if (data.subtitle!.contains('↓') || data.subtitle!.startsWith('-'))
                        const Icon(Icons.arrow_downward_rounded, size: 13, color: AppColors.error),
                      const SizedBox(width: 3),
                      Text(
                        data.subtitle!,
                        style: AppTypography.bodySmall.copyWith(
                          color: data.subtitle!.contains('↑') || data.subtitle!.startsWith('+')
                              ? AppColors.success
                              : (data.subtitle!.contains('↓') || data.subtitle!.startsWith('-')
                                  ? AppColors.error
                                  : cs.onSurfaceVariant),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
