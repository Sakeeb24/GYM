// lib/features/dashboard/presentation/owner_dashboard_screen.dart
// Gym Command Center — Owner Dashboard Experience
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => SupabaseDashboardRepository());

final dashboardStatsProvider = FutureProvider.family<DashboardStats, String>((ref, gymId) async {
  return ref.watch(dashboardRepositoryProvider).fetchStats(gymId);
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final gymId = profile.gymId;
    final asyncStats = ref.watch(dashboardStatsProvider(gymId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ownerName = (profile.fullName?.isNotEmpty == true)
        ? profile.fullName!.toUpperCase()
        : (profile.username?.toUpperCase() ?? 'COACH');

    final greeting = _getGreeting();

    return Scaffold(
      body: asyncStats.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardStatsProvider(gymId).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Athletic Greeting & Hero Heading ──────────────
                Text(
                  '$greeting, $ownerName',
                  style: AppTypography.labelAthletic.copyWith(
                    color: isDark ? AppColors.brand : AppColors.brandDark,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "LET'S GET STRONGER TODAY.",
                  style: AppTypography.displayMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 20),

                // ── 2. Hero Gym Performance Banner ───────────────────
                _HeroPerformanceCard(stats: stats),
                const SizedBox(height: 20),

                // ── 3. Quick Action Operations Bar ───────────────────
                Text(
                  'QUICK OPERATIONS',
                  style: AppTypography.labelAthletic.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                _QuickActionsBar(),
                const SizedBox(height: 24),

                // ── 4. 4-Card KPI Metric Grid ────────────────────────
                Text(
                  'PERFORMANCE METRICS',
                  style: AppTypography.labelAthletic.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                _MetricGrid(stats: stats),
                const SizedBox(height: 24),

                // ── 5. Retention & Peak Hours ────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatMiniCard(
                        title: 'RETENTION RATE',
                        value: '92.4%',
                        subtitle: '↑ 4.2% vs Q3',
                        color: AppColors.success,
                        icon: Icons.verified_user_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatMiniCard(
                        title: 'PEAK GYM HOURS',
                        value: '6 - 8 PM',
                        subtitle: '84 Active Athletes',
                        color: AppColors.flameStreak,
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── 6. Weekly Training Volume Bar Chart ──────────────
                Text(
                  'WEEKLY TRAINING VOLUME',
                  style: AppTypography.labelAthletic.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                _WeeklyVolumeCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load gym command center',
          onRetry: () => ref.refresh(dashboardStatsProvider(gymId).future),
        ),
      ),
    );
  }
}

class _HeroPerformanceCard extends StatelessWidget {
  final DashboardStats stats;
  const _HeroPerformanceCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final computedRate = stats.totalMembers > 0
        ? ((stats.checkedInToday / stats.totalMembers) * 100).clamp(0, 100).toInt()
        : 92;

    return Container(
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
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "TODAY'S GYM PERFORMANCE",
                    style: AppTypography.labelAthletic.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      '8.4%',
                      style: AppTypography.labelAthletic.copyWith(
                        color: AppColors.success,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$computedRate%',
                style: AppTypography.metricLarge.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 42,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ATTENDANCE RATE',
                style: AppTypography.labelAthletic.copyWith(
                  color: isDark ? AppColors.brand : AppColors.brandDark,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(
            progress: computedRate / 100.0,
            height: 8,
            color: isDark ? AppColors.brand : AppColors.brandDark,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ActionButton(
            label: '+ ADD MEMBER',
            icon: Icons.person_add_alt_1_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Athlete pre-enrollment is managed via the member registry.')),
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: '✓ CHECK IN',
            icon: Icons.qr_code_scanner_rounded,
            isHighlighted: true,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open the Check-in tab to scan member QR passes.')),
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: '💳 RECORD PAYMENT',
            icon: Icons.payments_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment transactions are synced with the billing engine.')),
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: '🔄 RENEW',
            icon: Icons.autorenew_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('View pending renewal reminders in the Renewals tab.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isHighlighted
              ? (isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer)
              : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlighted
                ? (isDark ? AppColors.brand : AppColors.brandDark)
                : cs.outline,
            width: isHighlighted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isHighlighted
                  ? (isDark ? AppColors.brand : AppColors.brandDark)
                  : cs.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 11,
                color: isHighlighted
                    ? (isDark ? AppColors.brand : AppColors.brandDark)
                    : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final DashboardStats stats;
  const _MetricGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          StatCard(
            data: StatCardData(
              title: 'ACTIVE MEMBERS',
              value: '${stats.totalMembers}',
              subtitle: '↑ 12% this month',
              icon: const Icon(Icons.groups_rounded),
              accentColor: AppColors.brand,
              isGlowing: true,
            ),
          ),
          StatCard(
            data: StatCardData(
              title: "TODAY'S CHECK-INS",
              value: '${stats.checkedInToday}',
              subtitle: 'Active Training Today',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              accentColor: AppColors.goldMedal,
            ),
          ),
          StatCard(
            data: StatCardData(
              title: 'EXPIRING SOON',
              value: '${stats.renewalsDue}',
              subtitle: 'Action required',
              icon: const Icon(Icons.autorenew_rounded),
              accentColor: AppColors.warning,
            ),
          ),
          StatCard(
            data: StatCardData(
              title: 'RED LIST ALERTS',
              value: '${stats.redListOpen}',
              subtitle: 'At-risk no-shows',
              icon: const Icon(Icons.local_fire_department_rounded),
              accentColor: AppColors.flameStreak,
            ),
          ),
        ];

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _StatMiniCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r16,
        border: Border.all(color: cs.outline),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.labelAthletic.copyWith(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyVolumeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
          _MiniDayBar(day: 'M', heightRatio: 0.80, count: '164'),
          _MiniDayBar(day: 'T', heightRatio: 0.95, count: '186', isMax: true),
          _MiniDayBar(day: 'W', heightRatio: 0.75, count: '152'),
          _MiniDayBar(day: 'T', heightRatio: 0.88, count: '174'),
          _MiniDayBar(day: 'F', heightRatio: 0.70, count: '142'),
          _MiniDayBar(day: 'S', heightRatio: 0.60, count: '120'),
          _MiniDayBar(day: 'S', heightRatio: 0.35, count: '75'),
        ],
      ),
    );
  }
}

class _MiniDayBar extends StatelessWidget {
  final String day;
  final double heightRatio;
  final String count;
  final bool isMax;

  const _MiniDayBar({
    required this.day,
    required this.heightRatio,
    required this.count,
    this.isMax = false,
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
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 9,
            color: isMax ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: maxHeight * heightRatio,
          decoration: BoxDecoration(
            color: isMax
                ? AppColors.brand
                : (isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt),
            borderRadius: BorderRadius.circular(4),
            boxShadow: isMax ? AppShadows.cyanGlow : null,
          ),
        ),
        const SizedBox(height: 6),
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
