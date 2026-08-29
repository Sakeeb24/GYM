// lib/features/dashboard/presentation/member_dashboard_screen.dart
// Clean Member Gym Pass & Training Overview (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
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

    final memberName = profile.fullName?.isNotEmpty == true
        ? profile.fullName!
        : (profile.username ?? 'Athlete');

    return Scaffold(
      body: asyncData.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.refresh(memberDashboardProvider(profile.userId).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Clean Digital Gym Pass ───────────────────────────────
                _CleanGymPass(
                  memberName: memberName,
                  memberNumber: data.memberNumber,
                  planName: data.planName,
                  status: data.membershipStatus,
                  expiresAt: data.expiresAt,
                ),
                const SizedBox(height: 16),

                // ── 2. Training Streak & Sessions ───────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SimpleMemberMetricCard(
                        title: 'Current Streak',
                        value: '${data.currentStreak} days',
                        subtitle: 'Best: ${data.longestStreak} days',
                        icon: Icons.local_fire_department_rounded,
                        accentColor: AppColors.flameStreak,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SimpleMemberMetricCard(
                        title: 'Total Sessions',
                        value: '${data.totalVisits}',
                        subtitle: 'All-time workouts',
                        icon: Icons.fitness_center_rounded,
                        accentColor: AppColors.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 3. Action ────────────────────────────────────────────────
                AppButton(
                  text: 'Scan QR to Check In',
                  height: 44,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrCheckInScreen()),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                ),
                const SizedBox(height: 20),

                // ── 4. Recent Workouts Log ──────────────────────────────────
                Text(
                  'Recent Sessions',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                if (data.recentVisits.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: AppRadii.r8,
                      border: Border.all(color: cs.outline),
                    ),
                    child: Center(
                      child: Text(
                        'No workouts logged yet. Scan the gym QR to record your first workout!',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.recentVisits.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final visit = data.recentVisits[index];
                      final dateStr = '${visit.year}-${visit.month.toString().padLeft(2, '0')}-${visit.day.toString().padLeft(2, '0')}';
                      final timeStr = '${visit.hour.toString().padLeft(2, '0')}:${visit.minute.toString().padLeft(2, '0')}';

                      return Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: AppRadii.r8,
                          border: Border.all(color: cs.outline),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                          title: Text(
                            'Workout Session',
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: Text(
                            '$dateStr at $timeStr',
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                          ),
                          trailing: const AppBadge(
                            label: 'Verified',
                            color: AppColors.statusActive,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load member pass',
          onRetry: () => ref.refresh(memberDashboardProvider(profile.userId).future),
        ),
      ),
    );
  }
}

class _CleanGymPass extends StatelessWidget {
  final String memberName;
  final String memberNumber;
  final String planName;
  final MembershipStatus status;
  final DateTime? expiresAt;

  const _CleanGymPass({
    required this.memberName,
    required this.memberNumber,
    required this.planName,
    required this.status,
    required this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        : 'Active';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r12,
        border: Border.all(
          color: isDark ? AppColors.brand.withAlpha(60) : cs.outline,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.brand),
                  const SizedBox(width: 6),
                  Text(
                    'LIFTFLOW PASS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.brand : AppColors.brandDark,
                    ),
                  ),
                ],
              ),
              AppBadge(label: status.name, color: statusColor),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            memberName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            planName,
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MEMBER ID', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  Text(memberNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('VALID THROUGH', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  Text(formattedExpiry, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleMemberMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _SimpleMemberMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r12,
        border: Border.all(color: cs.outline),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
