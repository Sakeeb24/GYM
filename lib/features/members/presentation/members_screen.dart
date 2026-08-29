// lib/features/members/presentation/members_screen.dart
// Clean, Compact Member Roster & Athlete Profiles (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/member.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Members',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
              // ── 1. Search Bar ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search members by name or ID...',
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: AppRadii.r8,
                      borderSide: BorderSide(color: cs.outline),
                    ),
                  ),
                ),
              ),

              // ── 2. Filter Chips ───────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: ['ALL', 'ACTIVE', 'INACTIVE'].map((f) {
                    final isSel = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(
                          f,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSel ? Colors.black : cs.onSurface,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        selected: isSel,
                        onSelected: (val) => setState(() => _filter = f),
                        selectedColor: AppColors.brand,
                        backgroundColor: cs.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isSel ? AppColors.brand : cs.outline),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),

              // ── 3. Compact Member Cards List ──────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? const AppEmptyState(
                        message: 'No members match your search criteria.',
                        icon: Icons.person_search_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (c, i) => _CompactMemberCard(
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
          message: 'Failed to load member roster',
          onRetry: () => ref.invalidate(membersProvider(profile.gymId)),
        ),
      ),
    );
  }
}

class _CompactMemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;

  const _CompactMemberCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r12,
        border: Border.all(color: cs.outline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.r12,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Name + Tier & Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Pro Membership • #LF-${member.memberNumber}',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppBadge(
                      label: member.isActive ? 'Active' : 'Inactive',
                      color: member.isActive ? AppColors.statusActive : AppColors.statusExpired,
                      showDot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Attendance + Streak Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '87% attendance',
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.local_fire_department_rounded, color: AppColors.flameStreak, size: 14),
                        SizedBox(width: 2),
                        Text(
                          '24 day streak',
                          style: TextStyle(
                            color: AppColors.flameStreak,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AppProgressBar(
                  progress: 0.87,
                  height: 4,
                  color: isDark ? AppColors.brand : AppColors.brandDark,
                ),
                const SizedBox(height: 8),

                // Bottom Row: Expiry + View Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expires in 18 days',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'View →',
                      style: TextStyle(
                        color: isDark ? AppColors.brand : AppColors.brandDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Section
            Text(
              member.fullName,
              style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'Pro Member • #LF-${member.memberNumber}',
              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),

            // Attendance / Streak / Membership Simple Table
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadii.r8,
                border: Border.all(color: cs.outline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  _DataRow(label: 'Attendance', value: '87%'),
                  const Divider(height: 16),
                  _DataRow(label: 'Streak', value: '24 days 🔥'),
                  const Divider(height: 16),
                  _DataRow(label: 'Membership', value: '68 days active'),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Text(
              'Recent Sessions',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _SimpleSessionRow(day: 'Today', time: '07:15 AM', session: 'Strength & Conditioning'),
            const SizedBox(height: 6),
            _SimpleSessionRow(day: 'Yesterday', time: '06:45 PM', session: 'Upper Body Workout'),
            const SizedBox(height: 6),
            _SimpleSessionRow(day: '2 days ago', time: '07:00 AM', session: 'Legs & Core'),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
        Text(value, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}

class _SimpleSessionRow extends StatelessWidget {
  final String day;
  final String time;
  final String session;

  const _SimpleSessionRow({required this.day, required this.time, required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r8,
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(session, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
          Text('$day $time', style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }
}
