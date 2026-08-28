// lib/core/widgets/app_stat_card.dart
import 'package:flutter/material.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

class StatCardData {
  final String title;
  final String value;
  final String? subtitle;
  final Widget? icon;

  const StatCardData({required this.title, required this.value, this.subtitle, this.icon});
}

class StatCard extends StatelessWidget {
  final StatCardData data;
  const StatCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r16,
        border: Border.all(color: cs.outlineVariant.withAlpha(128)),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.title, style: AppTypography.labelLarge.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          if (data.icon != null)
            DefaultTextStyle(
              style: TextStyle(color: cs.primary, fontSize: 20),
              child: data.icon!,
            ),
          Text(data.value,
              style: AppTypography.headlineSmall.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              )),
          if (data.subtitle != null)
            Text(data.subtitle!,
                style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
