// lib/features/members/presentation/members_screen.dart
// Fitness Athlete Roster & Interactive Athlete Performance Profiles
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/member.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';

final membersProvider = StreamProvider.autoDispose.family<List<Member>, String>((ref, gymId) {
  final client = AppSupabase.client;
  return client
      .from('members')
      .stream(primaryKey: ['id'])
      .eq('gym_id', gymId)
      .map((rows) => rows.map(Member.fromMap).toList());
});

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAthleteProfile(BuildContext context, Member member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AthleteProfileSheet(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final membersAsync = ref.watch(membersProvider(profile.gymId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.groups_rounded, size: 22, color: isDark ? AppColors.brand : AppColors.brandDark),
            const SizedBox(width: 10),
            Text(
              'ATHLETE ROSTER',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: membersAsync.when(
        data: (members) {
          final filtered = members.where((m) {
            final q = _query.toLowerCase();
            final matchesQuery = _query.isEmpty ||
                m.fullName.toLowerCase().contains(q) ||
                (m.phone != null && m.phone!.contains(q)) ||
                m.memberNumber.toLowerCase().contains(q);

            if (!matchesQuery) return false;

            if (_filter == 'ACTIVE') return m.isActive;
            if (_filter == 'INACTIVE') return !m.isActive;
            return true;
          }).toList();

          return Column(
            children: [
              // Search Input Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search athlete name, phone, or ID (#LF-)...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppRadii.r12,
                      borderSide: BorderSide(color: cs.outline),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: ['ALL', 'ACTIVE', 'INACTIVE'].map((f) {
                    final isSel = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          f,
                          style: AppTypography.labelAthletic.copyWith(
                            fontSize: 10,
                            color: isSel ? Colors.black : cs.onSurface,
                            fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                        selected: isSel,
                        onSelected: (val) => setState(() => _filter = f),
                        selectedColor: AppColors.brand,
                        backgroundColor: cs.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSel ? AppColors.brand : cs.outline),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              // Athlete List
              Expanded(
                child: filtered.isEmpty
                    ? const AppEmptyState(
                        message: 'No athletes match your search criteria.',
                        icon: Icons.person_search_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                        itemBuilder: (c, i) => _AthleteCard(
                          member: filtered[i],
                          onTap: () => _openAthleteProfile(context, filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, stack) => AppErrorState(
          message: 'Failed to load athlete roster',
          onRetry: () => ref.invalidate(membersProvider(profile.gymId)),
        ),
      ),
    );
  }
}

class _AthleteCard extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;

  const _AthleteCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initials = member.fullName.isNotEmpty
        ? member.fullName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
        : 'JD';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r16,
        border: Border.all(color: cs.outline, width: 1),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.r16,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name + ID + Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.dSurfaceElevated : AppColors.brandContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.brand.withAlpha(70) : AppColors.brandDark.withAlpha(70),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials.toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName.toUpperCase(),
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#LF-${member.memberNumber}',
                            style: AppTypography.labelAthletic.copyWith(
                              color: isDark ? AppColors.brand : AppColors.brandDark,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppBadge(
                      label: member.isActive ? 'ACTIVE' : 'INACTIVE',
                      color: member.isActive ? AppColors.statusActive : AppColors.statusExpired,
                      showDot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Membership & Streak Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PRO ATHLETE TIER',
                      style: AppTypography.labelAthletic.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.flameStreak, size: 16),
                        const SizedBox(width: 3),
                        Text(
                          '24 DAY STREAK',
                          style: AppTypography.labelAthletic.copyWith(
                            color: AppColors.flameStreak,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Attendance Rate Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ATTENDANCE',
                      style: AppTypography.labelAthletic.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '87%',
                      style: AppTypography.labelAthletic.copyWith(
                        color: isDark ? AppColors.brand : AppColors.brandDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const AppProgressBar(progress: 0.87, height: 6),
                const SizedBox(height: 10),

                // Footer Expiry Note
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EXPIRES IN 18 DAYS',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AthleteProfileSheet extends StatelessWidget {
  final Member member;
  const _AthleteProfileSheet({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initials = member.fullName.isNotEmpty
        ? member.fullName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
        : 'JD';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Section
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dSurfaceElevated : AppColors.brandContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brand, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      initials.toUpperCase(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.brand : AppColors.brandDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#LF-${member.memberNumber} • PRO MEMBER',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.brand : AppColors.brandDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (member.phone != null)
                        Text(
                          member.phone!,
                          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4 Athlete Statistics Cards
            Row(
              children: const [
                Expanded(
                  child: _MiniStatTile(
                    title: 'ATTENDANCE',
                    value: '87%',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.brand,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _MiniStatTile(
                    title: 'WORKOUTS',
                    value: '42',
                    icon: Icons.fitness_center_rounded,
                    color: AppColors.goldMedal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                Expanded(
                  child: _MiniStatTile(
                    title: 'STREAK',
                    value: '24 DAYS',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.flameStreak,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _MiniStatTile(
                    title: 'MEMBERSHIP',
                    value: '68 DAYS',
                    icon: Icons.verified_rounded,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Training Activity Breakdown
            Text(
              'RECENT TRAINING SESSIONS',
              style: AppTypography.labelAthletic.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            _SessionTile(day: 'Today', time: '07:15 AM', type: 'Strength & Conditioning'),
            const SizedBox(height: 8),
            _SessionTile(day: 'Yesterday', time: '06:45 PM', type: 'Hypertrophy Upper Body'),
            const SizedBox(height: 8),
            _SessionTile(day: '2 days ago', time: '07:00 AM', type: 'Legs & Core Power'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.labelAthletic.copyWith(
                  fontSize: 9,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String day;
  final String time;
  final String type;

  const _SessionTile({
    required this.day,
    required this.time,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 14, color: AppColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  '$day at $time',
                  style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
