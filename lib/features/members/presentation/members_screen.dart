// lib/features/members/presentation/members_screen.dart
// Clean, Compact Member Roster & Athlete Profiles (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/models/member.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
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
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),

              // ── 2. Filter Chips ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${members.length})',
                      selected: _filter == 'ALL',
                      onSelected: () => setState(() => _filter = 'ALL'),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Active (${members.where((m) => m.isActive).length})',
                      selected: _filter == 'ACTIVE',
                      onSelected: () => setState(() => _filter = 'ACTIVE'),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Inactive (${members.where((m) => !m.isActive).length})',
                      selected: _filter == 'INACTIVE',
                      onSelected: () => setState(() => _filter = 'INACTIVE'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── 3. Member Roster List ─────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? const AppEmptyState(
                        message: 'No members found matching your search query or filter criteria.',
                        icon: Icons.people_outline_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final member = filtered[index];
                          return _MemberRosterCard(
                            member: member,
                            onTap: () => _openAthleteProfile(context, member),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load members roster',
          onRetry: () => ref.refresh(membersProvider(profile.gymId).future),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
      side: BorderSide(
        color: selected
            ? (isDark ? AppColors.brand : AppColors.brandDark)
            : cs.outline,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _MemberRosterCard extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;

  const _MemberRosterCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: cs.surface,
      borderRadius: AppRadii.r12,
      child: InkWell(
        borderRadius: AppRadii.r12,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.r12,
            border: Border.all(color: cs.outline),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
                child: Text(
                  member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'M',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.brand : AppColors.brandDark,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#LF-${member.memberNumber} • ${member.phone ?? 'No Phone'}',
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: member.isActive ? 'ACTIVE' : 'INACTIVE',
                color: member.isActive ? AppColors.brand : AppColors.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AthleteProfileSheet extends StatefulWidget {
  final Member member;
  const _AthleteProfileSheet({required this.member});

  @override
  State<_AthleteProfileSheet> createState() => _AthleteProfileSheetState();
}

class _AthleteProfileSheetState extends State<_AthleteProfileSheet> {
  bool _loading = true;
  String _planName = 'Standard Plan';
  int _currentStreak = 0;
  int _totalVisits = 0;
  int _daysActive = 0;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadMemberDetails();
  }

  Future<void> _loadMemberDetails() async {
    if (!AppSupabase.isConfigured) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final client = AppSupabase.client;

    try {
      // 1. Membership info
      final memRes = await client
          .from('memberships')
          .select('started_at, expires_at, status, membership_plans(name)')
          .eq('member_id', widget.member.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (memRes != null) {
        final planData = memRes['membership_plans'];
        if (planData is Map && planData['name'] != null) {
          _planName = planData['name'].toString();
        }
        final startedAt = DateTime.tryParse(memRes['started_at']?.toString() ?? '');
        if (startedAt != null) {
          _daysActive = DateTime.now().difference(startedAt).inDays.clamp(1, 9999);
        }
      }

      // 2. Attendance history & streak calculation
      final attRes = await client
          .from('attendance')
          .select('id, check_in_at, source')
          .eq('member_id', widget.member.id)
          .order('check_in_at', ascending: false)
          .limit(20);

      _totalVisits = attRes.length;
      final dates = attRes
          .map((r) => DateTime.tryParse(r['check_in_at']?.toString() ?? ''))
            .whereType<DateTime>()
            .toList();

        final attendances = dates
            .map((d) => Attendance(
                  memberId: widget.member.id,
                  gymId: widget.member.gymId,
                  checkInAt: d,
                ))
            .toList();

      final streakRes = computeStreak(attendances);
      _currentStreak = streakRes.current;
      _sessions = List<Map<String, dynamic>>.from(attRes);
    } catch (_) {
      // Graceful fallback on network error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatSessionTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${diff.inDays} days ago';
  }

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
              widget.member.fullName,
              style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '$_planName • #LF-${widget.member.memberNumber}',
              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),

            if (_loading) ...[
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ] else ...[
              // Attendance / Streak / Membership Real Table
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: AppRadii.r8,
                  border: Border.all(color: cs.outline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    _DataRow(label: 'Total Visits', value: '$_totalVisits visits'),
                    const Divider(height: 16),
                    _DataRow(
                      label: 'Current Streak',
                      value: _currentStreak > 0 ? '$_currentStreak days 🔥' : '0 days',
                    ),
                    const Divider(height: 16),
                    _DataRow(
                      label: 'Membership',
                      value: _daysActive > 0 ? '$_daysActive days active' : (widget.member.isActive ? 'Active' : 'Inactive'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Recent Check-in Sessions',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              if (_sessions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: AppRadii.r8,
                    border: Border.all(color: cs.outline),
                  ),
                  child: Center(
                    child: Text(
                      'No check-in sessions recorded yet.',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ..._sessions.take(5).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: AppRadii.r8,
                          border: Border.all(color: cs.outline),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gym Check-in (${s['source'] ?? 'qr_self'})',
                              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            Text(
                              _formatSessionTime(s['check_in_at']?.toString()),
                              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 14),
            ],
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
