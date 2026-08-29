// lib/features/dashboard/presentation/member_dashboard_screen.dart
// Athlete Member Dashboard & Digital Gym Pass
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';
import '../../qr_checkin/presentation/qr_checkin_screen.dart';

class MemberDashboardData {
  final int currentStreak;
  final int longestStreak;
  final int totalVisits;
  final MembershipStatus membershipStatus;
  final DateTime? expiresAt;
  final String planName;
  final String memberNumber;
  final List<DateTime> recentVisits;

  const MemberDashboardData({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalVisits,
    required this.membershipStatus,
    required this.expiresAt,
    required this.planName,
    required this.memberNumber,
    required this.recentVisits,
  });
}

final memberDashboardProvider = FutureProvider.family<MemberDashboardData, String>((ref, userId) async {
  final client = AppSupabase.client;

  // 1. Fetch member record
  final memberRows = await client
      .from('members')
      .select('id, gym_id, member_number, full_name, status')
      .eq('profile_id', userId)
      .limit(1);

  if ((memberRows as List).isEmpty) {
    return const MemberDashboardData(
      currentStreak: 0,
      longestStreak: 0,
      totalVisits: 0,
      membershipStatus: MembershipStatus.inactive,
      expiresAt: null,
      planName: 'No Active Membership',
      memberNumber: '—',
      recentVisits: [],
    );
  }

  final memberId = memberRows[0]['id'] as String;
  final gymId = memberRows[0]['gym_id'] as String;
  final memberNumber = memberRows[0]['member_number'] as String? ?? '—';

  // 2. Fetch memberships with joined plan name
  final membershipRows = await client
      .from('memberships')
      .select('id, status, expires_at, plan_id, paused_until, canceled_at, started_at, membership_plans(name)')
      .eq('member_id', memberId)
      .order('created_at', ascending: false)
      .limit(1);

  MembershipStatus status = MembershipStatus.inactive;
  DateTime? expiresAt;
  String planName = 'Standard Membership';

  if ((membershipRows as List).isNotEmpty) {
    final m = membershipRows[0];
    expiresAt = m['expires_at'] != null ? DateTime.tryParse(m['expires_at'] as String) : null;
    final pausedUntil = m['paused_until'] != null ? DateTime.tryParse(m['paused_until'] as String) : null;
    final canceledAt = m['canceled_at'] != null ? DateTime.tryParse(m['canceled_at'] as String) : null;
    final startedAt = m['started_at'] != null ? DateTime.tryParse(m['started_at'] as String) ?? DateTime.now() : DateTime.now();

    final planData = m['membership_plans'];
    if (planData is Map && planData['name'] != null) {
      planName = planData['name'] as String;
    }

    final membership = Membership(
      id: m['id'] as String,
      memberId: memberId,
      gymId: gymId,
      startedAt: startedAt,
      expiresAt: expiresAt,
      pausedUntil: pausedUntil,
      canceledAt: canceledAt,
    );

    status = computeMembershipStatus(membership, SystemClock());
  }

  // 3. Fetch attendance history for streak & visits
  final attRows = await client
      .from('attendance')
      .select('check_in_at')
      .eq('member_id', memberId)
      .order('check_in_at', ascending: false)
      .limit(60);

  final checkInDates = (attRows as List)
      .map((r) => DateTime.tryParse(r['check_in_at'] as String? ?? ''))
      .whereType<DateTime>()
      .toList();

  final attendances = checkInDates
      .map((d) => Attendance(memberId: memberId, gymId: gymId, checkInAt: d))
      .toList();

  final streakResult = computeStreak(attendances);

  return MemberDashboardData(
    currentStreak: streakResult.current,
    longestStreak: streakResult.longest,
    totalVisits: checkInDates.length,
    membershipStatus: status,
    expiresAt: expiresAt,
    planName: planName,
    memberNumber: memberNumber,
    recentVisits: checkInDates.take(10).toList(),
  );
});

class MemberDashboardScreen extends ConsumerWidget {
  const MemberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final asyncData = ref.watch(memberDashboardProvider(profile.userId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final memberName = profile.fullName?.isNotEmpty == true
        ? profile.fullName!.toUpperCase()
        : (profile.username?.toUpperCase() ?? 'ATHLETE');

    return Scaffold(
      body: asyncData.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.refresh(memberDashboardProvider(profile.userId).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Digital Athlete Gym Pass ─────────────────────────────
                _DigitalGymPass(
                  memberName: memberName,
                  memberNumber: data.memberNumber,
                  planName: data.planName,
                  status: data.membershipStatus,
                  expiresAt: data.expiresAt,
                  isDark: isDark,
                  onScanTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrCheckInScreen()),
                  ),
                ),
                const SizedBox(height: 20),

                // ── 2. Training Streak & Performance KPIs ───────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StreakStatCard(
                        title: 'ACTIVE STREAK',
                        value: '${data.currentStreak}',
                        unit: 'DAYS',
                        icon: Icons.local_fire_department_rounded,
                        accentColor: AppColors.flameStreak,
                        subtitle: 'Personal Best: ${data.longestStreak} days',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StreakStatCard(
                        title: 'TOTAL SESSIONS',
                        value: '${data.totalVisits}',
                        unit: 'WORKOUTS',
                        icon: Icons.fitness_center_rounded,
                        accentColor: AppColors.brand,
                        subtitle: 'All-time check-ins',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── 3. Quick Actions ─────────────────────────────────────────
                AppButton(
                  text: 'SCAN GYM QR TO CHECK IN',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrCheckInScreen()),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                ),
                const SizedBox(height: 28),

                // ── 4. Recent Training Log ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECENT SESSIONS',
                      style: AppTypography.labelAthletic.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${data.recentVisits.length} recorded',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (data.recentVisits.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded, size: 36, color: cs.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(
                            'No workouts logged yet. Scan the gym QR to record your first workout!',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.recentVisits.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final visit = data.recentVisits[index];
                      return _WorkoutLogTile(visitDate: visit);
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load athlete profile',
          onRetry: () => ref.refresh(memberDashboardProvider(profile.userId).future),
        ),
      ),
    );
  }
}

// ── Digital Gym Pass Card Widget ─────────────────────────────────────────────
class _DigitalGymPass extends StatelessWidget {
  final String memberName;
  final String memberNumber;
  final String planName;
  final MembershipStatus status;
  final DateTime? expiresAt;
  final bool isDark;
  final VoidCallback onScanTap;

  const _DigitalGymPass({
    required this.memberName,
    required this.memberNumber,
    required this.planName,
    required this.status,
    required this.expiresAt,
    required this.isDark,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = switch (status) {
      MembershipStatus.active => AppColors.statusActive,
      MembershipStatus.expiring => AppColors.statusExpiring,
      MembershipStatus.paused => AppColors.statusPaused,
      MembershipStatus.expired => AppColors.statusExpired,
      MembershipStatus.canceled => AppColors.statusCanceled,
      _ => AppColors.statusExpired,
    };

    final formattedExpiry = expiresAt != null
        ? '${expiresAt!.year}-${expiresAt!.month.toString().padLeft(2, '0')}-${expiresAt!.day.toString().padLeft(2, '0')}'
        : 'Active Ongoing';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF131720), const Color(0xFF0D1016)]
              : [Colors.white, const Color(0xFFF1F5F9)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.brand.withAlpha(80) : AppColors.brandDark.withAlpha(60),
          width: 1.5,
        ),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Gym Logo & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, size: 20, color: AppColors.brand),
                  const SizedBox(width: 8),
                  Text(
                    'LIFTFLOW ATHLETE PASS',
                    style: AppTypography.labelAthletic.copyWith(
                      color: isDark ? AppColors.brand : AppColors.brandDark,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              AppBadge(label: status.name.toUpperCase(), color: statusColor),
            ],
          ),
          const SizedBox(height: 20),

          // Athlete Full Name
          Text(
            memberName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displaySmall.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),

          // Plan Name
          Text(
            planName.toUpperCase(),
            style: AppTypography.labelAthletic.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 14),

          // Pass metadata row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MEMBER ID', style: AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(memberNumber, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('VALID THROUGH', style: AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(formattedExpiry, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Athletic Streak / Metric Card Widget ─────────────────────────────────────
class _StreakStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color accentColor;
  final String subtitle;
  final bool isDark;

  const _StreakStatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accentColor,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? cs.outline : cs.outlineVariant),
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
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              Icon(icon, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.metricLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTypography.labelAthletic.copyWith(
                  color: accentColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Workout Log Tile Widget ──────────────────────────────────────────────────
class _WorkoutLogTile extends StatelessWidget {
  final DateTime visitDate;
  const _WorkoutLogTile({required this.visitDate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dateStr = '${visitDate.year}-${visitDate.month.toString().padLeft(2, '0')}-${visitDate.day.toString().padLeft(2, '0')}';
    final timeStr = '${visitDate.hour.toString().padLeft(2, '0')}:${visitDate.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
        ),
        title: Text(
          'Gym Training Session',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$dateStr • $timeStr',
          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: AppBadge(
          label: 'VERIFIED',
          color: AppColors.statusActive,
        ),
      ),
    );
  }
}
