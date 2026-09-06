// lib/features/memberships/presentation/member_membership_screen.dart
// Member Membership Plan & Pass Overview (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
import '../../renewals/presentation/renewals_screen.dart';

class MemberMembershipData {
  final String planName;
  final MembershipStatus status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int daysRemaining;
  final List<String> benefits;
  final String memberNumber;
  final String gymName;

  MemberMembershipData({
    required this.planName,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.daysRemaining,
    required this.benefits,
    required this.memberNumber,
    required this.gymName,
  });
}

final memberMembershipDetailsProvider = FutureProvider.autoDispose.family<MemberMembershipData, String>((ref, userId) async {
  final client = AppSupabase.client;

  // 1. Resolve member
  final memberRows = await client
      .from('members')
      .select('id, gym_id, member_number, full_name, gyms(name)')
      .eq('profile_id', userId)
      .limit(1);

  if ((memberRows as List).isEmpty) {
    return MemberMembershipData(
      planName: 'No Active Membership',
      status: MembershipStatus.inactive,
      startedAt: null,
      expiresAt: null,
      daysRemaining: 0,
      benefits: [],
      memberNumber: '—',
      gymName: 'LiftFlow Gym',
    );
  }

  final memberId = memberRows[0]['id'] as String;
  final gymId = memberRows[0]['gym_id'] as String;
  final memberNumber = memberRows[0]['member_number'] as String? ?? '—';
  final gymData = memberRows[0]['gyms'];
  final gymName = (gymData is Map && gymData['name'] != null) ? gymData['name'] as String : 'LiftFlow Gym';

  // 2. Resolve latest membership
  final memRows = await client
      .from('memberships')
      .select('id, status, started_at, expires_at, paused_until, canceled_at, membership_plans(name, duration_days, price_cents)')
      .eq('member_id', memberId)
      .order('created_at', ascending: false)
      .limit(1);

  if ((memRows as List).isEmpty) {
    return MemberMembershipData(
      planName: 'Standard Athlete Pass',
      status: MembershipStatus.inactive,
      startedAt: null,
      expiresAt: null,
      daysRemaining: 0,
      benefits: ['Full Gym Floor Access', 'Locker & Shower Access', 'Free Fitness Assessment'],
      memberNumber: memberNumber,
      gymName: gymName,
    );
  }

  final m = memRows[0];
  final startedAt = m['started_at'] != null ? DateTime.tryParse(m['started_at'] as String) : null;
  final expiresAt = m['expires_at'] != null ? DateTime.tryParse(m['expires_at'] as String) : null;
  final pausedUntil = m['paused_until'] != null ? DateTime.tryParse(m['paused_until'] as String) : null;
  final canceledAt = m['canceled_at'] != null ? DateTime.tryParse(m['canceled_at'] as String) : null;

  String planName = 'Annual All-Access';
  final planData = m['membership_plans'];
  if (planData is Map && planData['name'] != null) {
    planName = planData['name'] as String;
  }

  final membership = Membership(
    id: m['id'] as String,
    memberId: memberId,
    gymId: gymId,
    startedAt: startedAt ?? DateTime.now(),
    expiresAt: expiresAt,
    pausedUntil: pausedUntil,
    canceledAt: canceledAt,
  );

  final status = computeMembershipStatus(membership, SystemClock());
  final daysRemaining = expiresAt != null ? expiresAt.difference(DateTime.now()).inDays.clamp(0, 365) : 0;

  return MemberMembershipData(
    planName: planName,
    status: status,
    startedAt: startedAt,
    expiresAt: expiresAt,
    daysRemaining: daysRemaining,
    benefits: [
      'Full Gym Floor & Free Weights Access',
      'Cardio & Functional Training Zone',
      'Locker & Changing Room Amenities',
      'Daily QR Fast Check-in Pass',
      'Workout Tracking & Progress Analytics',
    ],
    memberNumber: memberNumber,
    gymName: gymName,
  );
});

class MemberMembershipScreen extends ConsumerWidget {
  const MemberMembershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();

    final dataAsync = ref.watch(memberMembershipDetailsProvider(profile.userId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MEMBERSHIP PASS',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: dataAsync.when(
        data: (data) {
          final isExpiring = data.status == MembershipStatus.expiring || data.daysRemaining <= 14;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Digital Membership Pass Card ───────────────────────────
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dSurface : AppColors.lSurface,
                    borderRadius: AppRadii.card,
                    border: Border.all(
                      color: isDark ? AppColors.brand.withAlpha(60) : AppColors.brandDark.withAlpha(60),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.brandGlow,
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.gymName.toUpperCase(),
                                style: AppTypography.labelAthletic.copyWith(
                                  fontSize: 14,
                                  color: isDark ? AppColors.brand : AppColors.brandDark,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'MEMBER ID: #${data.memberNumber}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          AppBadge.status(data.status.name),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        data.planName,
                        style: AppTypography.headlineLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, size: 16, color: isExpiring ? AppColors.warning : AppColors.brand),
                          const SizedBox(width: 6),
                          Text(
                            data.expiresAt != null
                                ? '${data.daysRemaining} days remaining (Expires ${DateFormat('d MMM yyyy').format(data.expiresAt!)})'
                                : 'Active Membership',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isExpiring ? AppColors.warning : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 2. Membership Benefits ────────────────────────────────────
                Text(
                  'PLAN INCLUSIONS & BENEFITS',
                  style: AppTypography.labelAthletic.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                ...data.benefits.map((benefit) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            benefit,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // ── 3. Renewal Action ─────────────────────────────────────────
                AppButton(
                  text: isExpiring ? 'Renew Membership Now' : 'Upgrade or Extend Plan',
                  icon: const Icon(Icons.autorenew_rounded),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RenewalsScreen()),
                    );
                  },
                  fullWidth: true,
                ),
              ],
            ),
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(message: e.toString()),
      ),
    );
  }
}
