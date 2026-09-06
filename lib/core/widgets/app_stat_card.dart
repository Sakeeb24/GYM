// lib/core/widgets/app_stat_card.dart
// Clean, Flat Gym Metric Card (Apex Precision)
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
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
        borderRadius: AppRadii.r12,
        border: Border.all(color: cs.outline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.r12,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data.icon != null)
                      IconTheme(
                        data: IconThemeData(color: accent, size: 18),
                        child: data.icon!,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data.value,
                  style: AppTypography.metricLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                if (data.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: data.subtitle!.contains('↑') || data.subtitle!.startsWith('+')
                          ? AppColors.success
                          : (data.subtitle!.contains('↓') || data.subtitle!.startsWith('-')
                              ? AppColors.error
                              : cs.onSurfaceVariant),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
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
