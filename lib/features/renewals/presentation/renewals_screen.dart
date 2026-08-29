// lib/features/renewals/presentation/renewals_screen.dart
// Gym Membership Renewal Tracking
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';

final renewalsProvider = StreamProvider.family<List<Map<String, dynamic>>, ({String gymId, AppRole role, String userId})>((ref, args) {
  final client = AppSupabase.client;

  if (args.role == AppRole.member) {
    return client
        .from('renewal_orders')
        .stream(primaryKey: ['id'])
        .eq('gym_id', args.gymId)
        .map((rows) => rows);
  }

  return client
      .from('renewal_orders')
      .stream(primaryKey: ['id'])
      .eq('gym_id', args.gymId)
      .map((rows) => rows);
});

class RenewalsScreen extends ConsumerWidget {
  const RenewalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final asyncOrders = ref.watch(renewalsProvider((
      gymId: profile.gymId,
      role: profile.role,
      userId: profile.userId,
    )));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.autorenew_rounded, size: 22, color: isDark ? AppColors.brand : AppColors.brandDark),
            const SizedBox(width: 10),
            Text(
              'MEMBERSHIP RENEWALS',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: asyncOrders.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const AppEmptyState(
              message: 'No pending membership renewals due.',
              icon: Icons.check_circle_outline_rounded,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: orders.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final o = orders[index];
              final due = DateTime.tryParse(o['due_at'] as String? ?? '');
              final amount = ((o['amount_cents'] as num? ?? 0) / 100).toStringAsFixed(2);
              final currency = (o['currency'] as String? ?? 'USD').toUpperCase();
              final stage = (o['reminder_stage'] as String? ?? 'pending').replaceAll('_', ' ').toUpperCase();
              final status = (o['status'] as String? ?? 'pending').toUpperCase();

              final dateStr = due != null
                  ? '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}'
                  : 'Due Soon';

              return Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline),
                  boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timer_outlined, color: AppColors.warning, size: 22),
                  ),
                  title: Text(
                    'Membership Renewal • \$$amount $currency',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        'Due date: $dateStr • Stage: $stage',
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  trailing: AppBadge(
                    label: status,
                    color: status == 'PAID' ? AppColors.statusActive : AppColors.statusExpiring,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load renewals',
          onRetry: () => ref.invalidate(renewalsProvider),
        ),
      ),
    );
  }
}
