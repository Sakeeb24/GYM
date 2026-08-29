// lib/features/dashboard/presentation/member_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../auth/auth_notifier.dart';
import '../../qr_checkin/presentation/qr_checkin_screen.dart';

class MemberDashboardData {
  final int currentStreak;
  final int longestStreak;
  final int totalVisits;
  final MembershipStatus membershipStatus;
  final DateTime? expiresAt;
  final String planName;
  final List<DateTime> recentVisits;

  const MemberDashboardData({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalVisits,
    required this.membershipStatus,
    required this.expiresAt,
    required this.planName,
    required this.recentVisits,
  });
}

final memberDashboardProvider = FutureProvider.family<MemberDashboardData, String>((ref, userId) async {
  final client = AppSupabase.client;

  // 1. Fetch member record
  final memberRows = await client
      .from('members')
      .select('id, gym_id, full_name, is_active')
      .eq('user_id', userId)
      .limit(1);

  if ((memberRows as List).isEmpty) {
    return const MemberDashboardData(
      currentStreak: 0,
      longestStreak: 0,
      totalVisits: 0,
      membershipStatus: MembershipStatus.expired,
      expiresAt: null,
      planName: 'No Active Plan',
      recentVisits: [],
    );
  }

  final memberId = memberRows[0]['id'] as String;
  final gymId = memberRows[0]['gym_id'] as String;

  // 2. Fetch memberships
  final membershipRows = await client
      .from('memberships')
      .select('id, status, expires_at, plan_id, paused_until, canceled_at, started_at')
      .eq('member_id', memberId)
      .order('created_at', ascending: false)
      .limit(1);

  MembershipStatus status = MembershipStatus.expired;
  DateTime? expiresAt;
  String planName = 'Standard Membership';

  if ((membershipRows as List).isNotEmpty) {
    final m = membershipRows[0];
    expiresAt = m['expires_at'] != null ? DateTime.tryParse(m['expires_at'] as String) : null;
    final pausedUntil = m['paused_until'] != null ? DateTime.tryParse(m['paused_until'] as String) : null;
    final canceledAt = m['canceled_at'] != null ? DateTime.tryParse(m['canceled_at'] as String) : null;
    final startedAt = m['started_at'] != null ? DateTime.tryParse(m['started_at'] as String) ?? DateTime.now() : DateTime.now();

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

  // 3. Fetch attendance history
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
    recentVisits: checkInDates.take(5).toList(),
  );
});

class MemberDashboardScreen extends ConsumerWidget {
  const MemberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final asyncData = ref.watch(memberDashboardProvider(profile.userId));
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Gym Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authActionsProvider).signOut(),
          ),
        ],
      ),
      body: asyncData.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.refresh(memberDashboardProvider(profile.userId).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${profile.fullName ?? profile.email ?? 'Member'}!',
                  style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _MembershipCard(data: data),
                const SizedBox(height: 20),
                _StreakStats(data: data),
                const SizedBox(height: 24),
                Text('Quick Actions', style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Open QR Scanner / Check-in',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QrCheckInScreen()),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Recent Visits', style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (data.recentVisits.isEmpty)
                  const Text('No recent check-ins recorded.')
                else
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.recentVisits.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final d = data.recentVisits[i];
                        return ListTile(
                          leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                          title: Text('Check-in on ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'),
                          subtitle: Text('Time: ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load member dashboard',
          onRetry: () => ref.refresh(memberDashboardProvider(profile.userId).future),
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final MemberDashboardData data;
  const _MembershipCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (data.membershipStatus) {
      MembershipStatus.active => AppColors.success,
      MembershipStatus.expiring => AppColors.warning,
      MembershipStatus.paused || MembershipStatus.frozen => const Color(0xFF6B7280),
      MembershipStatus.expired || MembershipStatus.canceled || MembershipStatus.inactive => AppColors.error,
    };

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data.planName, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                AppBadge(
                  label: data.membershipStatus.name.toUpperCase(),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.expiresAt != null)
              Text(
                'Expires: ${data.expiresAt!.year}-${data.expiresAt!.month.toString().padLeft(2, '0')}-${data.expiresAt!.day.toString().padLeft(2, '0')}',
                style: AppTypography.bodyMedium,
              )
            else
              Text('Continuous access', style: AppTypography.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _StreakStats extends StatelessWidget {
  final MemberDashboardData data;
  const _StreakStats({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            data: StatCardData(
              title: 'Current Streak',
              value: '${data.currentStreak} Days',
              icon: const Icon(Icons.local_fire_department, color: Colors.orange),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            data: StatCardData(
              title: 'Longest Streak',
              value: '${data.longestStreak} Days',
              icon: const Icon(Icons.emoji_events, color: Colors.amber),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            data: StatCardData(
              title: 'Total Visits',
              value: '${data.totalVisits}',
              icon: const Icon(Icons.fitness_center, color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }
}
