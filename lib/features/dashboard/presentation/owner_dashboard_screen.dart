// lib/features/dashboard/presentation/owner_dashboard_screen.dart
// Gym Command Center — Owner Dashboard
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../features/auth/auth_notifier.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => SupabaseDashboardRepository());

final dashboardStatsProvider = FutureProvider.family<DashboardStats, String>((ref, gymId) async {
  return ref.watch(dashboardRepositoryProvider).fetchStats(gymId);
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

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
        : 'COACH';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.fitness_center_rounded, size: 22, color: isDark ? AppColors.brand : AppColors.brandDark),
            const SizedBox(width: 10),
            Text(
              'LIFTFLOW COMMAND',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authActionsProvider).signOut(),
          ),
        ],
      ),
      body: asyncStats.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardStatsProvider(gymId).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting & Motivation
                Text(
                  'WELCOME, $ownerName',
                  style: AppTypography.labelAthletic.copyWith(
                    color: isDark ? AppColors.brand : AppColors.brandDark,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "LET'S GET STRONGER TODAY.",
                  style: AppTypography.displayMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Top Gym Performance Highlight Banner
                _PerformanceBanner(stats: stats),
                const SizedBox(height: 20),

                // Performance Section Title
                Text(
                  'GYM METRICS',
                  style: AppTypography.labelAthletic.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),

                // 4-Card Metric Grid
                _MetricGrid(stats: stats),
                const SizedBox(height: 24),
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

class _PerformanceBanner extends StatelessWidget {
  final DashboardStats stats;
  const _PerformanceBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final attendanceRate = stats.totalMembers > 0
        ? ((stats.checkedInToday / stats.totalMembers) * 100).clamp(0, 100).toInt()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.brand.withAlpha(60) : cs.outline,
          width: 1.5,
        ),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 10),
                Text(
                  '$attendanceRate%',
                  style: AppTypography.metricLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ATTENDANCE RATE',
                  style: AppTypography.labelAthletic.copyWith(
                    color: isDark ? AppColors.brand : AppColors.brandDark,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withAlpha(80)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: 6),
                Text(
                  '↑ ACTIVE',
                  style: AppTypography.labelAthletic.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        final width = constraints.maxWidth;
        final cards = [
          StatCard(
            data: StatCardData(
              title: 'ACTIVE MEMBERS',
              value: '${stats.totalMembers}',
              subtitle: 'Enrolled Athletes',
              icon: const Icon(Icons.groups_rounded),
            ),
          ),
          StatCard(
            data: StatCardData(
              title: "TODAY'S CHECK-INS",
              value: '${stats.checkedInToday}',
              subtitle: 'Active Training Today',
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
          ),
          StatCard(
            data: StatCardData(
              title: 'RED LIST ALERTS',
              value: '${stats.redListOpen}',
              subtitle: 'At-risk / No-shows',
              icon: const Icon(Icons.local_fire_department_rounded, color: AppColors.flameStreak),
            ),
          ),
          StatCard(
            data: StatCardData(
              title: 'RENEWALS DUE',
              value: '${stats.renewalsDue}',
              subtitle: 'Expiring Memberships',
              icon: const Icon(Icons.autorenew_rounded),
            ),
          ),
        ];

        final cols = (width / 200).floor().clamp(1, 4);
        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}
