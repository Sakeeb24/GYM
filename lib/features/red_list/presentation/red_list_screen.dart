// lib/features/red_list/presentation/red_list_screen.dart
// At-Risk Member Retention Center (Red List)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_notifier.dart';
import '../no_show_repository.dart';
import '../../../core/models/no_show_case.dart';

class RedListScreen extends ConsumerWidget {
  const RedListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final asyncCases = ref.watch(openCasesProvider(profile.gymId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, size: 22, color: AppColors.flameStreak),
            const SizedBox(width: 10),
            Text(
              'RETENTION RED LIST',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: asyncCases.when(
        data: (cases) => cases.isEmpty
            ? const AppEmptyState(
                message: 'All athletes are active and training! No retention alerts.',
                icon: Icons.check_circle_outline_rounded,
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: cases.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (c, i) => Dismissible(
                  key: ValueKey(cases[i].id),
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                          'RESOLVE CASE',
                          style: AppTypography.labelAthletic.copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (direction) async {
                    await ref.read(noShowRepositoryProvider).resolveCase(cases[i].id, 'resolved', 'returned');
                  },
                  child: _CaseCard(caseItem: cases[i]),
                ),
              ),
        loading: () => const AppLoadingState(),
        error: (e, stack) => AppErrorState(
          message: 'Failed to load retention red list',
          onRetry: () {
            ref.invalidate(openCasesProvider(profile.gymId));
          },
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final NoShowCase caseItem;
  const _CaseCard({required this.caseItem});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(80), width: 1.2),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.error.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
        ),
        title: Text(
          caseItem.memberName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              caseItem.reason.toUpperCase(),
              style: AppTypography.labelAthletic.copyWith(
                color: AppColors.flameStreak,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Opened ${_formatDate(caseItem.createdAt)} • Swipe to resolve',
              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        trailing: AppBadge(
          label: caseItem.status,
          color: _statusColor(caseItem.status),
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s.toLowerCase()) {
    'open' => AppColors.statusOpen,
    'resolved' => AppColors.statusResolved,
    _ => AppColors.statusExpiring,
  };

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
