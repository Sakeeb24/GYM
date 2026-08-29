// lib/core/widgets/app_stat_card.dart
// Gym Performance & KPI Metric Card
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

  const StatCardData({
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
  });
}

class StatCard extends StatelessWidget {
  final StatCardData data;
  const StatCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r12,
        border: Border.all(color: cs.outline),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
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
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data.icon != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconTheme(
                    data: IconThemeData(
                      color: isDark ? AppColors.brand : AppColors.brandDark,
                      size: 18,
                    ),
                    child: data.icon!,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: AppTypography.metricMedium.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (data.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              data.subtitle!,
              style: AppTypography.bodySmall.copyWith(
                color: data.subtitle!.startsWith('+') || data.subtitle!.contains('↑')
                    ? AppColors.success
                    : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
