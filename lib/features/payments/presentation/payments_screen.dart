// lib/features/payments/presentation/payments_screen.dart
// Gym Revenue & Payment Transactions
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../auth/auth_notifier.dart';

final recentPaymentsProvider = StreamProvider.family<List<Map<String, dynamic>>, ({String gymId, AppRole role, String userId})>((ref, args) {
  final client = AppSupabase.client;

  return client
      .from('payments')
      .stream(primaryKey: ['id'])
      .eq('gym_id', args.gymId)
      .map((rows) {
        final sorted = [...rows]..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
        return sorted.take(50).toList();
      });
});

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final isOwner = profile.role == AppRole.owner;
    final isMember = profile.role == AppRole.member;

    final asyncPayments = ref.watch(recentPaymentsProvider((
      gymId: profile.gymId,
      role: profile.role,
      userId: profile.userId,
    )));

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.payments_rounded, size: 22, color: isDark ? AppColors.brand : AppColors.brandDark),
            const SizedBox(width: 10),
            Text(
              isMember ? 'MY PAYMENTS' : 'PAYMENTS & REVENUE',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: asyncPayments.when(
        data: (payments) {
          final totalRevenueCents = payments.fold<int>(
            0,
            (acc, p) => p['status'] == 'succeeded'
                ? acc + ((p['amount_cents'] as num?)?.toInt() ?? 0)
                : acc,
          );
          final formattedRevenue = (totalRevenueCents / 100).toStringAsFixed(2);

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(recentPaymentsProvider((
              gymId: profile.gymId,
              role: profile.role,
              userId: profile.userId,
            )).future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue Performance Card (Owners & Staff)
                  if (!isMember) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.brand.withAlpha(60) : cs.outline,
                          width: 1.5,
                        ),
                        boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL REVENUE RECORDED',
                                style: AppTypography.labelAthletic.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ACTIVE',
                                      style: AppTypography.labelAthletic.copyWith(
                                        color: AppColors.success,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '\$$formattedRevenue',
                            style: AppTypography.metricLarge.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Text(
                    isMember ? 'PAYMENT HISTORY' : 'RECENT TRANSACTIONS',
                    style: AppTypography.labelAthletic.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (payments.isEmpty)
                    const AppEmptyState(
                      message: 'No transactions recorded yet.',
                      icon: Icons.receipt_long_rounded,
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final p = payments[i];
                        final status = p['status'] as String? ?? 'pending';
                        final amount = ((p['amount_cents'] as num? ?? 0) / 100).toStringAsFixed(2);
                        final currency = (p['currency'] as String? ?? 'USD').toUpperCase();
                        final color = switch (status) {
                          'succeeded' => AppColors.statusActive,
                          'failed' => AppColors.statusExpired,
                          'pending' => AppColors.statusExpiring,
                          _ => cs.onSurfaceVariant,
                        };

                        return Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outline),
                            boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.credit_card_rounded, color: color, size: 20),
                            ),
                            title: Text(
                              '\$$amount $currency',
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              p['provider_reference'] as String? ?? 'Membership Payment',
                              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                            trailing: AppBadge(label: status.toUpperCase(), color: color),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load payments',
          onRetry: () => ref.refresh(recentPaymentsProvider((
            gymId: profile.gymId,
            role: profile.role,
            userId: profile.userId,
          )).future),
        ),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refunds are processed securely via the Stripe portal.')),
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(
                'STRIPE PORTAL',
                style: AppTypography.labelAthletic.copyWith(color: Colors.black),
              ),
            )
          : null,
    );
  }
}
