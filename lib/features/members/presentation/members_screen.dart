// lib/features/members/presentation/members_screen.dart
// Fitness Member Database Roster with Live Athlete Search
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/member.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return m.fullName.toLowerCase().contains(q) ||
                (m.phone != null && m.phone!.contains(q)) ||
                m.memberNumber.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              // Search Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by athlete name, phone, or ID...',
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
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: filtered.isEmpty
                    ? const AppEmptyState(
                        message: 'No enrolled athletes match your search.',
                        icon: Icons.person_search_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (c, i) => _MemberCard(member: filtered[i]),
                      ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, stack) => AppErrorState(
          message: 'Failed to load athlete roster',
          onRetry: () {
            ref.invalidate(membersProvider(profile.gymId));
          },
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline, width: 1),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.brand.withAlpha(60) : AppColors.brandDark.withAlpha(60),
            ),
          ),
          child: Center(
            child: Text(
              member.memberNumber,
              style: AppTypography.labelAthletic.copyWith(
                color: isDark ? AppColors.brand : AppColors.brandDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        title: Text(
          member.fullName,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.phone_rounded, size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              member.phone ?? member.email ?? 'No contact info',
              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        trailing: AppBadge(
          label: member.isActive ? 'ACTIVE' : 'INACTIVE',
          color: member.isActive ? AppColors.statusActive : AppColors.statusExpired,
        ),
      ),
    );
  }
}
