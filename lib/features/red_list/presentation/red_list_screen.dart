// lib/features/red_list/presentation/red_list_screen.dart
// At-Risk Member Retention Center (Red List)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_notifier.dart';
import '../no_show_repository.dart';
import '../../../core/models/no_show_case.dart';

class RedListScreen extends ConsumerStatefulWidget {
  const RedListScreen({super.key});

  @override
  ConsumerState<RedListScreen> createState() => _RedListScreenState();
}

class _RedListScreenState extends ConsumerState<RedListScreen> {
  String _activeCategory = 'ALL';

  @override
  Widget build(BuildContext context) {
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
        data: (cases) {
          final categories = ['ALL', 'AT RISK', 'EXPIRING SOON', 'OVERDUE', 'INACTIVE'];

          return Column(
            children: [
              // Category Filter Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: categories.map((cat) {
                    final isSel = _activeCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          cat,
                          style: AppTypography.labelAthletic.copyWith(
                            fontSize: 10,
                            color: isSel ? Colors.black : cs.onSurface,
                            fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                        selected: isSel,
                        onSelected: (val) => setState(() => _activeCategory = cat),
                        selectedColor: isSel && cat == 'AT RISK' ? AppColors.flameStreak : AppColors.brand,
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

              // Cases List
              Expanded(
                child: cases.isEmpty
                    ? const AppEmptyState(
                        message: 'All athletes are active and training! No retention alerts.',
                        icon: Icons.check_circle_outline_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: cases.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (c, i) => _RetentionCard(
                          caseItem: cases[i],
                          onResolve: () async {
                            await ref.read(noShowRepositoryProvider).resolveCase(cases[i].id, 'resolved', 'returned');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Resolved retention case for ${cases[i].memberName}')),
                              );
                            }
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, stack) => AppErrorState(
          message: 'Failed to load retention red list',
          onRetry: () => ref.invalidate(openCasesProvider(profile.gymId)),
        ),
      ),
    );
  }
}

class _RetentionCard extends StatelessWidget {
  final NoShowCase caseItem;
  final VoidCallback onResolve;

  const _RetentionCard({
    required this.caseItem,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r16,
        border: Border.all(
          color: AppColors.flameStreak.withAlpha(90),
          width: 1.5,
        ),
        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.flameStreak.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.flameStreak),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.flameStreak, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'AT RISK',
                          style: AppTypography.labelAthletic.copyWith(
                            color: AppColors.flameStreak,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppBadge(
                label: caseItem.status.toUpperCase(),
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Athlete Name
          Text(
            caseItem.memberName.toUpperCase(),
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Retention Details
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Last visit: 12 days ago • Reason: ${caseItem.reason}',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: const [
              Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.warning),
              SizedBox(width: 6),
              Text(
                'Membership: Expires in 3 days',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons: [ CONTACT ] and [ RENEW ]
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'CONTACT',
                  variant: AppButtonVariant.outlined,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening WhatsApp outreach for ${caseItem.memberName}...')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  text: 'RENEW & RESOLVE',
                  variant: AppButtonVariant.filled,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  onPressed: onResolve,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
