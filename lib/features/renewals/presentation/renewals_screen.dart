// lib/features/renewals/presentation/renewals_screen.dart
// Clean Membership Renewal Tracking (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
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
    final cs = Theme.of(context).colorScheme;

    final asyncOrders = ref.watch(renewalsProvider((
      gymId: profile.gymId,
      role: profile.role,
      userId: profile.userId,
    )));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Renewals',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: orders.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final o = orders[index];
              final due = DateTime.tryParse(o['due_at'] as String? ?? '');
              final amount = ((o['amount_cents'] as num? ?? 0) / 100).toStringAsFixed(2);
              final currency = (o['currency'] as String? ?? 'USD').toUpperCase();
              final stage = (o['reminder_stage'] as String? ?? 'pending').replaceAll('_', ' ').toLowerCase();
              final status = (o['status'] as String? ?? 'pending').toLowerCase();

              final dateStr = due != null
                  ? '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}'
                  : 'Due Soon';

              return Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: AppRadii.r8,
                  border: Border.all(color: cs.outline),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined, color: AppColors.warning, size: 18),
                  ),
                  title: Text(
                    'Membership Renewal • \$$amount $currency',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Due date: $dateStr • Stage: $stage',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                  trailing: AppBadge(
                    label: status,
                    color: status == 'paid' ? AppColors.statusActive : AppColors.statusExpiring,
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
