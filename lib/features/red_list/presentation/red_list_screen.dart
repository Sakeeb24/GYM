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

          final filteredCases = cases.where((c) {
            if (_activeCategory == 'ALL') return true;
            final reason = c.reason.toLowerCase();
            if (_activeCategory == 'AT RISK') {
              return reason.contains('inactive') || reason.contains('risk') || reason.contains('absence');
            }
            if (_activeCategory == 'EXPIRING SOON') {
              return reason.contains('expir');
            }
            if (_activeCategory == 'OVERDUE') {
              return reason.contains('overdue') || reason.contains('unpaid') || reason.contains('payment');
            }
            if (_activeCategory == 'INACTIVE') {
              return c.status.toLowerCase() == 'open';
            }
            return true;
          }).toList();

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
                child: filteredCases.isEmpty
                    ? const AppEmptyState(
                        message: 'No members require attention.',
                        icon: Icons.check_circle_outline_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredCases.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (c, i) => _CleanRetentionCard(
                          caseItem: filteredCases[i],
                          onResolve: () async {
                            await ref.read(noShowRepositoryProvider).resolveCase(
                                  filteredCases[i].id,
                                  'resolved',
                                  'Outreach completed / renewed',
                                );
                            ref.invalidate(openCasesProvider(profile.gymId));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Resolved retention case for ${filteredCases[i].memberName}'),
                                  backgroundColor: AppColors.brand,
                                ),
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
          message: 'Unable to load Red List. Please try again.',
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

  String _formatLastSeen(DateTime? dt) {
    if (dt == null) return 'No recorded visits';
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return 'Visited today';
    if (days == 1) return 'Visited yesterday';
    return '$days days ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lastSeenStr = _formatLastSeen(caseItem.lastSeenAt);

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
                children: const [
                  Icon(Icons.local_fire_department_rounded, color: AppColors.flameStreak, size: 16),
                  SizedBox(width: 4),
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
                label: caseItem.status.toUpperCase(),
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
            'Last visit: $lastSeenStr • Reason: ${caseItem.reason}',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
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
                      SnackBar(content: Text('Opening outreach channel for ${caseItem.memberName}...')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  text: 'Resolve',
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
