// lib/features/red_list/presentation/red_list_screen.dart
// Clean At-Risk Retention Center (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
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
        title: Text(
          'Retention & Red List',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: categories.map((cat) {
                    final isSel = _activeCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSel ? Colors.black : cs.onSurface,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        selected: isSel,
                        onSelected: (val) => setState(() => _activeCategory = cat),
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
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (c, i) => _CleanRetentionCard(
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

class _CleanRetentionCard extends StatelessWidget {
  final NoShowCase caseItem;
  final VoidCallback onResolve;

  const _CleanRetentionCard({
    required this.caseItem,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.r12,
        border: Border.all(color: AppColors.flameStreak.withAlpha(80)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: AppColors.flameStreak, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'At Risk',
                    style: TextStyle(
                      color: AppColors.flameStreak,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              AppBadge(
                label: caseItem.status,
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            caseItem.memberName,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            'Last visit: 12 days ago • Reason: ${caseItem.reason}',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            'Membership: Expires in 3 days',
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Contact',
                  variant: AppButtonVariant.outlined,
                  height: 38,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening WhatsApp outreach for ${caseItem.memberName}...')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  text: 'Renew & Resolve',
                  variant: AppButtonVariant.filled,
                  height: 38,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
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
