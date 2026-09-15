import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/models/member.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';
import 'add_member_dialog.dart';
import 'edit_member_dialog.dart';
import 'export_roster_dialog.dart';
import 'member_contact_launcher.dart';
import 'renew_membership_dialog.dart';

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
  String _sort = 'A_Z'; // 'A_Z', 'Z_A', 'NEWEST', 'OLDEST'
  String? _selectedTag;

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

  void _openExportDialog(List<Member> allMembers, List<Member> filteredMembers) {
    showDialog(
      context: context,
      builder: (_) => ExportRosterDialog(
        allMembers: allMembers,
        filteredMembers: filteredMembers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final membersAsync = ref.watch(membersProvider(profile.gymId));
    final cs = Theme.of(context).colorScheme;

    return membersAsync.when(
      data: (members) {
        // Collect all unique tags
        final allTags = <String>{};
        for (final m in members) {
          allTags.addAll(m.tags);
        }

        final filtered = members.where((m) {
          final q = _query.toLowerCase();
          final matchesQuery = _query.isEmpty ||
              m.fullName.toLowerCase().contains(q) ||
              (m.phone != null && m.phone!.contains(q)) ||
              m.memberNumber.toLowerCase().contains(q) ||
              m.tags.any((t) => t.toLowerCase().contains(q));

          if (!matchesQuery) return false;

          if (_filter == 'ACTIVE' && !m.isActive) return false;
          if (_filter == 'INACTIVE' && m.isActive) return false;

          if (_selectedTag != null && !m.tags.contains(_selectedTag)) return false;

          return true;
        }).toList();

        // Apply sorting
        filtered.sort((a, b) {
          switch (_sort) {
            case 'Z_A':
              return b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase());
            case 'NEWEST':
              final aDate = a.createdAt ?? DateTime(2020);
              final bDate = b.createdAt ?? DateTime(2020);
              return bDate.compareTo(aDate);
            case 'OLDEST':
              final aDate = a.createdAt ?? DateTime(2020);
              final bDate = b.createdAt ?? DateTime(2020);
              return aDate.compareTo(bDate);
            case 'A_Z':
            default:
              return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          }
        });

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'MEMBERS ROSTER',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 16,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Export CSV',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () => _openExportDialog(members, filtered),
              ),
              IconButton(
                tooltip: 'Enroll Athlete',
                icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.brand),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AddMemberDialog(),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // ── 1. Search Bar ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search members by name, ID, or tag...',
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

              // ── 2. Status Filters & Sort Dropdown ─────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
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
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Sort Roster',
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: AppRadii.r8,
                          border: Border.all(color: cs.outline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort_rounded, size: 16, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              _sort == 'A_Z'
                                  ? 'A-Z'
                                  : _sort == 'Z_A'
                                      ? 'Z-A'
                                      : _sort == 'NEWEST'
                                          ? 'Newest'
                                          : 'Oldest',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSelected: (val) => setState(() => _sort = val),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'A_Z', child: Text('Name (A → Z)')),
                        const PopupMenuItem(value: 'Z_A', child: Text('Name (Z → A)')),
                        const PopupMenuItem(value: 'NEWEST', child: Text('Newest Joined')),
                        const PopupMenuItem(value: 'OLDEST', child: Text('Oldest Joined')),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 3. Tag Filter Chips (if any exist) ────────────────────
              if (allTags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'TAGS:',
                          style: AppTypography.labelAthletic.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.0,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TagFilterChip(
                          label: 'All Tags',
                          selected: _selectedTag == null,
                          onSelected: () => setState(() => _selectedTag = null),
                        ),
                        ...allTags.map((tag) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _TagFilterChip(
                                label: tag,
                                selected: _selectedTag == tag,
                                onSelected: () => setState(() {
                                  _selectedTag = _selectedTag == tag ? null : tag;
                                }),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // ── 4. Member Roster List ─────────────────────────────────
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
          ),
        );
      },
      loading: () => const Scaffold(body: AppLoadingState()),
      error: (e, _) => Scaffold(
        body: AppErrorState(
          message: 'Failed to load members roster',
          onRetry: () => ref.refresh(membersProvider(profile.gymId).future),
        ),
      ),
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _TagFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.brand.withAlpha(35) : AppColors.brandContainer)
              : cs.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? AppColors.brand : cs.outline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurfaceVariant,
          ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              if (member.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: member.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.brand.withAlpha(20) : AppColors.brandContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.brand.withAlpha(40)),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.brand : AppColors.brandDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AthleteProfileSheet extends ConsumerStatefulWidget {
  final Member member;
  const _AthleteProfileSheet({required this.member});

  @override
  ConsumerState<_AthleteProfileSheet> createState() => _AthleteProfileSheetState();
}

class _AthleteProfileSheetState extends ConsumerState<_AthleteProfileSheet> {
  late Member _currentMember;
  bool _loading = true;
  String _planName = 'Standard Plan';
  DateTime? _expiresAt;
  DateTime? _startedAt;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalVisits = 0;
  int _daysActive = 0;
  List<Map<String, dynamic>> _sessions = [];
  bool _loggingCheckIn = false;
  bool _togglingStatus = false;

  @override
  void initState() {
    super.initState();
    _currentMember = widget.member;
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
          .eq('member_id', _currentMember.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (memRes != null) {
        final planData = memRes['membership_plans'];
        if (planData is Map && planData['name'] != null) {
          _planName = planData['name'].toString();
        }
        _startedAt = DateTime.tryParse(memRes['started_at']?.toString() ?? '');
        _expiresAt = DateTime.tryParse(memRes['expires_at']?.toString() ?? '');

        if (_startedAt != null) {
          _daysActive = DateTime.now().difference(_startedAt!).inDays.clamp(1, 9999);
        }
      }

      // 2. Attendance history & streak calculation
      final attRes = await client
          .from('attendance')
          .select('id, check_in_at, source')
          .eq('member_id', _currentMember.id)
          .order('check_in_at', ascending: false)
          .limit(30);

      _totalVisits = (attRes as List).length;
      final dates = attRes
          .map((r) => DateTime.tryParse(r['check_in_at']?.toString() ?? ''))
          .whereType<DateTime>()
          .toList();

      final attendances = dates
          .map((d) => Attendance(
                memberId: _currentMember.id,
                gymId: _currentMember.gymId,
                checkInAt: d,
              ))
          .toList();

      final streakRes = computeStreak(attendances);
      _currentStreak = streakRes.current;
      _longestStreak = streakRes.longest;
      _sessions = List<Map<String, dynamic>>.from(attRes);
    } catch (_) {
      // Graceful fallback on network error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleMemberStatus() async {
    final nextStatus = _currentMember.isActive ? 'inactive' : 'active';
    setState(() => _togglingStatus = true);

    try {
      if (AppSupabase.isConfigured) {
        await AppSupabase.client
            .from('members')
            .update({'status': nextStatus})
            .eq('id', _currentMember.id);
      }

      if (mounted) {
        setState(() {
          _currentMember = _currentMember.copyWith(status: nextStatus);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_currentMember.fullName} status updated to ${nextStatus.toUpperCase()}'),
            backgroundColor: nextStatus == 'active' ? AppColors.brand : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorMapper.toUserMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingStatus = false);
    }
  }

  void _openPassQrDialog() {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.r16),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: AppColors.brand, size: 22),
            const SizedBox(width: 8),
            Text(
              'Digital Gym Pass',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
              ),
              child: QrImageView(
                data: 'LF-PASS-${_currentMember.gymId}-${_currentMember.memberNumber}',
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF111316),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF111316),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _currentMember.fullName,
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              'Pass #LF-${_currentMember.memberNumber} • $_planName',
              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualCheckIn() async {
    setState(() => _loggingCheckIn = true);
    try {
      final client = AppSupabase.client;
      final idem = 'manual_${_currentMember.id}_${DateTime.now().millisecondsSinceEpoch}';

      if (AppSupabase.isConfigured) {
        await client.from('attendance').insert({
          'gym_id': _currentMember.gymId,
          'member_id': _currentMember.id,
          'source': 'manual',
          'check_in_at': DateTime.now().toUtc().toIso8601String(),
          'idempotency_key': idem,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Manual check-in logged for ${_currentMember.fullName}'),
            backgroundColor: AppColors.brand,
          ),
        );
        await _loadMemberDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorMapper.toUserMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingCheckIn = false);
    }
  }

  void _openEditDialog() async {
    final updated = await showDialog<Member>(
      context: context,
      builder: (_) => EditMemberDialog(member: _currentMember),
    );

    if (updated != null && mounted) {
      setState(() => _currentMember = updated);
      _loadMemberDetails();
    }
  }

  void _openRenewDialog() async {
    final renewed = await showDialog<bool>(
      context: context,
      builder: (_) => RenewMembershipDialog(
        member: _currentMember,
        currentPlanName: _planName,
        currentExpiresAt: _expiresAt,
      ),
    );

    if (renewed == true && mounted) {
      _loadMemberDetails();
    }
  }

  void _openQuickContactDialog() {
    showDialog(
      context: context,
      builder: (_) => MemberQuickContactDialog(
        member: _currentMember,
        membershipExpiresAt: _expiresAt,
      ),
    );
  }

  String _formatSessionTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${diff.inDays} days ago (${dt.month}/${dt.day})';
  }

  String _getExpirySubtitle() {
    if (_expiresAt == null) return 'No expiration set';
    final now = DateTime.now();
    final diff = _expiresAt!.difference(now).inDays;
    final dateFormatted = '${_expiresAt!.year}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}';
    if (diff < 0) {
      return 'Expired ($dateFormatted)';
    } else if (diff == 0) {
      return 'Expires today ($dateFormatted)';
    } else if (diff <= 7) {
      return 'Expires in $diff days ($dateFormatted)';
    } else {
      return 'Active until $dateFormatted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

            // ── Header Section ──────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
                  child: Text(
                    _currentMember.fullName.isNotEmpty ? _currentMember.fullName[0].toUpperCase() : 'M',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.brand : AppColors.brandDark,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _currentMember.fullName,
                              style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _togglingStatus ? null : _toggleMemberStatus,
                            child: AppBadge(
                              label: _currentMember.isActive ? 'ACTIVE' : 'INACTIVE',
                              color: _currentMember.isActive ? AppColors.brand : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#LF-${_currentMember.memberNumber} • ${_currentMember.phone ?? 'No Phone'}',
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_currentMember.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _currentMember.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.brand.withAlpha(40)),
                    ),
                    child: Text(
                      tag,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.brand : AppColors.brandDark,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // ── Quick Action Bar ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: _openEditDialog,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.autorenew_rounded,
                    label: 'Renew',
                    onTap: _openRenewDialog,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.qr_code_2_rounded,
                    label: 'Pass QR',
                    onTap: _openPassQrDialog,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.send_rounded,
                    label: 'Message',
                    onTap: _openQuickContactDialog,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _QuickActionButton(
                    icon: _loggingCheckIn ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded,
                    label: 'Check In',
                    color: isDark ? AppColors.brand : AppColors.brandDark,
                    onTap: _loggingCheckIn ? null : _handleManualCheckIn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading) ...[
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ] else ...[
              // ── Membership Info Card ──────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dSurface : cs.surface,
                  borderRadius: AppRadii.r12,
                  border: Border.all(color: cs.outline),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MEMBERSHIP TIER',
                              style: AppTypography.labelAthletic.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _planName,
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_expiresAt != null && _expiresAt!.isBefore(DateTime.now()))
                                ? AppColors.error.withAlpha(20)
                                : AppColors.brand.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (_expiresAt != null && _expiresAt!.isBefore(DateTime.now()))
                                  ? AppColors.error
                                  : (isDark ? AppColors.brand : AppColors.brandDark),
                            ),
                          ),
                          child: Text(
                            _getExpirySubtitle(),
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: (_expiresAt != null && _expiresAt!.isBefore(DateTime.now()))
                                  ? AppColors.error
                                  : (isDark ? AppColors.brand : AppColors.brandDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _DataRow(label: 'Total Check-ins', value: '$_totalVisits visits'),
                    const Divider(height: 16),
                    _DataRow(
                      label: 'Current Streak',
                      value: _currentStreak > 0 ? '$_currentStreak days 🔥' : '0 days',
                    ),
                    const Divider(height: 16),
                    _DataRow(
                      label: 'Longest Streak',
                      value: '$_longestStreak days',
                    ),
                    const Divider(height: 16),
                    _DataRow(
                      label: 'Account Active',
                      value: _daysActive > 0 ? '$_daysActive days' : (_currentMember.isActive ? 'Active' : 'Inactive'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Recent Attendance Sessions ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Check-in Sessions',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${_sessions.length} total',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
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
                ..._sessions.take(6).map((s) {
                  final src = (s['source'] as String? ?? 'qr_self').toLowerCase();
                  final isManual = src == 'manual';

                  return Padding(
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
                          Row(
                            children: [
                              Icon(
                                isManual ? Icons.edit_calendar_rounded : Icons.qr_code_scanner_rounded,
                                size: 16,
                                color: isManual ? AppColors.warning : AppColors.brand,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isManual ? 'Manual Check-in' : 'QR Scan ($src)',
                                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            _formatSessionTime(s['check_in_at']?.toString()),
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetColor = color ?? (isDark ? Colors.white : AppColors.lTextPrimary);

    return Material(
      color: cs.surface,
      borderRadius: AppRadii.r8,
      child: InkWell(
        borderRadius: AppRadii.r8,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.r8,
            border: Border.all(color: cs.outline),
          ),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: targetColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: targetColor,
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

