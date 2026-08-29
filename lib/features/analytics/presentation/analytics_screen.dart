// lib/features/analytics/presentation/analytics_screen.dart
// Clean Gym Performance Insights & Attendance Trends (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_stat_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Insights & Attendance',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Today's Attendance Overview ───────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadii.r12,
                border: Border.all(color: cs.outline),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Attendance",
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Peak Hours: 6 PM — 8 PM',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.flameStreak,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '186 Check-ins',
                    style: AppTypography.metricLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '87.8% average monthly attendance rate (↑ 4.2%)',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Metric Grid ──────────────────────────────────────────
            Row(
              children: const [
                Expanded(
                  child: StatCard(
                    data: StatCardData(
                      title: 'Retention Rate',
                      value: '92.4%',
                      subtitle: '↑ 2.1% vs Q3',
                      icon: Icon(Icons.verified_user_outlined),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    data: StatCardData(
                      title: 'Active Streaks',
                      value: '142',
                      subtitle: '🔥 7+ consecutive days',
                      icon: Icon(Icons.local_fire_department_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 3. Weekly Attendance Distribution ───────────────────────
            Text(
              'Weekly Volume',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadii.r12,
                border: Border.all(color: cs.outline),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _SimpleDayBar(day: 'M', ratio: 0.85, count: '172'),
                  _SimpleDayBar(day: 'T', ratio: 0.95, count: '194', isPeak: true),
                  _SimpleDayBar(day: 'W', ratio: 0.80, count: '160'),
                  _SimpleDayBar(day: 'T', ratio: 0.90, count: '182'),
                  _SimpleDayBar(day: 'F', ratio: 0.75, count: '150'),
                  _SimpleDayBar(day: 'S', ratio: 0.65, count: '130'),
                  _SimpleDayBar(day: 'S', ratio: 0.40, count: '85'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. Peak Floor Hours ─────────────────────────────────────
            Text(
              'Peak Floor Traffic',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadii.r12,
                border: Border.all(color: cs.outline),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _SimpleTrafficRow(time: '06:00 AM – 09:00 AM', label: 'Morning Rush', count: '64 athletes', ratio: 0.75),
                  const SizedBox(height: 10),
                  _SimpleTrafficRow(time: '12:00 PM – 02:00 PM', label: 'Midday Session', count: '38 athletes', ratio: 0.45),
                  const SizedBox(height: 10),
                  _SimpleTrafficRow(time: '05:00 PM – 08:00 PM', label: 'Peak Evening', count: '84 athletes', ratio: 0.95, isPeak: true),
                  const SizedBox(height: 10),
                  _SimpleTrafficRow(time: '08:00 PM – 10:00 PM', label: 'Night Session', count: '42 athletes', ratio: 0.50),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SimpleDayBar extends StatelessWidget {
  final String day;
  final double ratio;
  final String count;
  final bool isPeak;

  const _SimpleDayBar({
    required this.day,
    required this.ratio,
    required this.count,
    this.isPeak = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const maxHeight = 70.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 10,
            color: isPeak ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurfaceVariant,
            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 18,
          height: maxHeight * ratio,
          decoration: BoxDecoration(
            color: isPeak
                ? (isDark ? AppColors.brand : AppColors.brandDark)
                : cs.outline,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            color: isPeak ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurfaceVariant,
            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SimpleTrafficRow extends StatelessWidget {
  final String time;
  final String label;
  final String count;
  final double ratio;
  final bool isPeak;

  const _SimpleTrafficRow({
    required this.time,
    required this.label,
    required this.count,
    required this.ratio,
    this.isPeak = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$time ($label)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                color: isPeak ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurface,
              ),
            ),
            Text(
              count,
              style: TextStyle(
                fontSize: 11,
                color: isPeak ? AppColors.flameStreak : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AppProgressBar(
          progress: ratio,
          height: 4,
          color: isPeak ? AppColors.flameStreak : (isDark ? AppColors.brand : AppColors.brandDark),
        ),
      ],
    );
  }
}
