// lib/features/analytics/presentation/analytics_screen.dart
// Athletic Gym Performance & Operations Analytics
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../auth/auth_notifier.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isStaff = profile?.role != AppRole.member;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.insights_rounded, size: 22, color: isDark ? AppColors.brand : AppColors.brandDark),
            const SizedBox(width: 10),
            Text(
              isStaff ? 'GYM PERFORMANCE & ANALYTICS' : 'ATHLETE PERFORMANCE INSIGHTS',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero Performance Metric ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadii.r16,
                border: Border.all(
                  color: isDark ? AppColors.brand.withAlpha(70) : cs.outline,
                  width: 1.5,
                ),
                boxShadow: isDark ? AppShadows.cyanGlow : AppShadows.sm,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isStaff ? 'ANNUAL GYM RETENTION RATE' : 'CONSISTENCY SCORE',
                        style: AppTypography.labelAthletic.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const AppBadge(
                        label: 'HIGH PERFORMANCE',
                        color: AppColors.success,
                        variant: BadgeVariant.solid,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '92.4%',
                        style: AppTypography.metricLarge.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 38,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.success),
                          Text(
                            '+4.2% vs last quarter',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const AppProgressBar(progress: 0.924, height: 8, color: AppColors.brand),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 2. Primary KPI Grid ─────────────────────────────────────────
            Text(
              'PERFORMANCE GAUGES',
              style: AppTypography.labelAthletic.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Expanded(
                  child: StatCard(
                    data: StatCardData(
                      title: 'Avg Attendance',
                      value: '87.8%',
                      subtitle: '↑ 6.1% this month',
                      icon: Icon(Icons.trending_up_rounded),
                      accentColor: AppColors.success,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    data: StatCardData(
                      title: 'Active Streaks',
                      value: '142',
                      subtitle: '🔥 7+ Days active',
                      icon: Icon(Icons.local_fire_department_rounded),
                      accentColor: AppColors.flameStreak,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                  child: StatCard(
                    data: StatCardData(
                      title: 'Renewal Rate',
                      value: '94.2%',
                      subtitle: '↑ 2.4% vs last cycle',
                      icon: Icon(Icons.autorenew_rounded),
                      accentColor: AppColors.brand,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    data: StatCardData(
                      title: 'Daily Check-ins',
                      value: '186',
                      subtitle: 'Peak: 6 PM - 8 PM',
                      icon: Icon(Icons.qr_code_scanner_rounded),
                      accentColor: AppColors.goldMedal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 3. Peak Gym Hours Breakdown ─────────────────────────────────
            Text(
              'PEAK GYM FLOOR TRAFFIC',
              style: AppTypography.labelAthletic.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadii.r16,
                border: Border.all(color: cs.outline),
                boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _TrafficHourRow(time: '06:00 AM - 09:00 AM (Morning Rush)', ratio: 0.75, count: '64 Athletes'),
                  const SizedBox(height: 12),
                  _TrafficHourRow(time: '12:00 PM - 02:00 PM (Midday Session)', ratio: 0.45, count: '38 Athletes'),
                  const SizedBox(height: 12),
                  _TrafficHourRow(time: '05:00 PM - 08:00 PM (Peak Prime)', ratio: 0.95, count: '84 Athletes', isPeak: true),
                  const SizedBox(height: 12),
                  _TrafficHourRow(time: '08:00 PM - 10:00 PM (Night Owls)', ratio: 0.50, count: '42 Athletes'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 4. Weekly Attendance Distribution ───────────────────────────
            Text(
              'WEEKLY TRAINING VOLUME',
              style: AppTypography.labelAthletic.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadii.r16,
                border: Border.all(color: cs.outline),
                boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _DayBar(day: 'MON', heightRatio: 0.85, count: '172'),
                  _DayBar(day: 'TUE', heightRatio: 0.95, count: '194', isMax: true),
                  _DayBar(day: 'WED', heightRatio: 0.80, count: '160'),
                  _DayBar(day: 'THU', heightRatio: 0.90, count: '182'),
                  _DayBar(day: 'FRI', heightRatio: 0.75, count: '150'),
                  _DayBar(day: 'SAT', heightRatio: 0.65, count: '130'),
                  _DayBar(day: 'SUN', heightRatio: 0.40, count: '85'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TrafficHourRow extends StatelessWidget {
  final String time;
  final double ratio;
  final String count;
  final bool isPeak;

  const _TrafficHourRow({
    required this.time,
    required this.ratio,
    required this.count,
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
            Row(
              children: [
                if (isPeak) ...[
                  const Icon(Icons.local_fire_department_rounded, color: AppColors.flameStreak, size: 16),
                  const SizedBox(width: 4),
                ],
                Text(
                  time,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                    color: isPeak ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurface,
                  ),
                ),
              ],
            ),
            Text(
              count,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: isPeak ? AppColors.flameStreak : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppProgressBar(
          progress: ratio,
          height: 6,
          color: isPeak ? AppColors.flameStreak : (isDark ? AppColors.brand : AppColors.brandDark),
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  final String day;
  final double heightRatio;
  final String count;
  final bool isMax;

  const _DayBar({
    required this.day,
    required this.heightRatio,
    required this.count,
    this.isMax = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const maxHeight = 100.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 9,
            color: isMax ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 24,
          height: maxHeight * heightRatio,
          decoration: BoxDecoration(
            color: isMax
                ? AppColors.brand
                : (isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt),
            borderRadius: BorderRadius.circular(6),
            border: isMax ? null : Border.all(color: cs.outline),
            boxShadow: isMax ? AppShadows.cyanGlow : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 10,
            color: isMax ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurfaceVariant,
            fontWeight: isMax ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
