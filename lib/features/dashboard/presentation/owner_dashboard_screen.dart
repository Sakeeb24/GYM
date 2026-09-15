import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../dashboard_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../auth/auth_notifier.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => SupabaseDashboardRepository());

final dashboardStatsProvider = FutureProvider.family<DashboardStats, String>((ref, gymId) async {
  return ref.watch(dashboardRepositoryProvider).fetchStats(gymId);
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final gymId = profile.gymId;
    final asyncStats = ref.watch(dashboardStatsProvider(gymId));
    final cs = Theme.of(context).colorScheme;

    final ownerName = (profile.fullName?.isNotEmpty == true)
        ? profile.fullName!
        : (profile.username ?? 'Coach');

    final greeting = _getGreeting();

    return Scaffold(
      body: asyncStats.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardStatsProvider(gymId).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Clean Header Greeting ──────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, $ownerName',
                            style: AppTypography.headlineLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Here is your real-time gym performance summary",
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 2. Real Attendance Hero Card ──────────────────────
                _AttendanceHeroCard(stats: stats),
                const SizedBox(height: 16),

                // ── 3. Real 2x2 Metric Grid ───────────────────────────
                _MetricGrid(stats: stats),
                const SizedBox(height: 20),

                // ── 4. Quick Actions Row ──────────────────────────────
                Text(
                  'Quick Actions',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _QuickActionsRow(),
                const SizedBox(height: 20),

                // ── 5. Real Recent Activity List ──────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    if (stats.recentActivity.isNotEmpty)
                      Text(
                        '${stats.recentActivity.length} check-ins',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _RecentActivityList(activity: stats.recentActivity),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load gym dashboard',
          onRetry: () => ref.refresh(dashboardStatsProvider(gymId).future),
        ),
      ),
    );
  }
}

class _AttendanceHeroCard extends StatelessWidget {
  final DashboardStats stats;
  const _AttendanceHeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final computedRate = stats.totalMembers > 0
        ? ((stats.checkedInToday / stats.totalMembers) * 100).clamp(0, 100).toInt()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurface : cs.surface,
        borderRadius: AppRadii.r12,
        border: Border.all(
          color: isDark ? AppColors.brand.withAlpha(40) : cs.outline,
          width: isDark ? 1.2 : 1.0,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppColors.brand.withAlpha(12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Today Check-in Rate',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? AppColors.brand.withAlpha(60) : AppColors.brandDark.withAlpha(60),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: AppTypography.labelAthletic.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                '${stats.checkedInToday} of ${stats.totalMembers} active members',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.brand : AppColors.brandDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$computedRate%',
                style: AppTypography.metricLarge.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                stats.checkedInToday == 0
                    ? 'Awaiting first athlete check-in'
                    : '${stats.checkedInToday} check-in${stats.checkedInToday > 1 ? 's' : ''} recorded today',
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppProgressBar(
            progress: computedRate / 100.0,
            height: 7,
            color: isDark ? AppColors.brand : AppColors.brandDark,
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends ConsumerWidget {
  final DashboardStats stats;
  const _MetricGrid({required this.stats});

  String _formatRevenue(int cents) {
    if (cents <= 0) return '₹0';
    final rupees = cents / 100;
    if (rupees >= 100000) {
      return '₹${(rupees / 100000).toStringAsFixed(1)}L';
    }
    if (rupees >= 1000) {
      return '₹${(rupees / 1000).toStringAsFixed(1)}k';
    }
    return '₹${rupees.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = [
      StatCard(
        data: StatCardData(
          title: 'Active Members',
          value: '${stats.totalMembers}',
          subtitle: '${stats.totalMembers} enrolled',
          icon: const Icon(Icons.people_alt_outlined),
          accentColor: AppColors.brand,
        ),
        onTap: () => ref.read(mainNavigationIndexProvider.notifier).state = 1,
      ),
      StatCard(
        data: StatCardData(
          title: "Today's Check-ins",
          value: '${stats.checkedInToday}',
          subtitle: stats.checkedInToday == 1 ? '1 athlete visited' : '${stats.checkedInToday} visits today',
          icon: const Icon(Icons.qr_code_scanner_outlined),
          accentColor: AppColors.brand,
        ),
        onTap: () => ref.read(mainNavigationIndexProvider.notifier).state = 2,
      ),
      StatCard(
        data: StatCardData(
          title: 'Expiring Soon',
          value: '${stats.expiringMembers}',
          subtitle: 'In next 7 days',
          icon: const Icon(Icons.timer_outlined),
          accentColor: stats.expiringMembers > 0 ? AppColors.warning : null,
        ),
        onTap: () => ref.read(mainNavigationIndexProvider.notifier).state = 4,
      ),
      StatCard(
        data: StatCardData(
          title: 'Monthly Revenue',
          value: _formatRevenue(stats.monthlyRevenueCents),
          subtitle: 'MTD collections',
          icon: const Icon(Icons.currency_rupee_rounded),
          accentColor: AppColors.success,
        ),
        onTap: () => ref.read(mainNavigationIndexProvider.notifier).state = 6,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }
}

class _QuickActionsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            label: '+ Member',
            icon: Icons.person_add_alt_1_outlined,
            onTap: () => context.push('/activate-member'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionChip(
            label: 'Scan QR',
            icon: Icons.qr_code_scanner_rounded,
            isPrimary: true,
            onTap: () => ref.read(mainNavigationIndexProvider.notifier).state = 3,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionChip(
            label: 'Payments',
            icon: Icons.payments_outlined,
            onTap: () => ref.read(mainNavigationIndexProvider.notifier).state = 6,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionChip(
            label: 'Renewals',
            icon: Icons.autorenew_outlined,
            onTap: () => ref.read(mainNavigationIndexProvider.notifier).state = 4,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isPrimary
          ? (isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer)
          : cs.surface,
      borderRadius: AppRadii.r8,
      child: InkWell(
        borderRadius: AppRadii.r8,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: AppRadii.r8,
            border: Border.all(
              color: isPrimary
                  ? (isDark ? AppColors.brand : AppColors.brandDark)
                  : cs.outline,
            ),
            boxShadow: isPrimary && isDark
                ? [
                    BoxShadow(
                      color: AppColors.brand.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: isPrimary
                    ? (isDark ? AppColors.brand : AppColors.brandDark)
                    : cs.onSurface,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? (isDark ? AppColors.brand : AppColors.brandDark)
                      : cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<RecentActivityItem> activity;
  const _RecentActivityList({required this.activity});

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activity.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: AppRadii.r12,
          border: Border.all(color: cs.outline),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.history_rounded, size: 28, color: cs.onSurfaceVariant.withAlpha(160)),
              ),
              const SizedBox(height: 10),
              Text(
                'No check-in activity recorded yet today',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.r12,
        side: BorderSide(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activity.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final item = activity[i];
          final initial = item.memberName.isNotEmpty ? item.memberName[0].toUpperCase() : 'A';

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.brand : AppColors.brandDark,
                ),
              ),
            ),
            title: Text(
              item.memberName,
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            subtitle: Text(
              'Pass #${item.memberNumber} • ${item.source}',
              style: AppTypography.bodySmall.copyWith(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.outline, width: 0.8),
              ),
              child: Text(
                _formatTime(item.checkInAt),
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
