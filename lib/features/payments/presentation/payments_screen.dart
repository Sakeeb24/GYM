// lib/features/payments/presentation/payments_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../auth/auth_notifier.dart';

final recentPaymentsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  final client = AppSupabase.client;
  return client.from('payments').stream(primaryKey: ['id']).eq('gym_id', gymId).map((rows) {
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
    final asyncPayments = ref.watch(recentPaymentsProvider(profile.gymId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: asyncPayments.when(
        data: (payments) => payments.isEmpty
            ? const AppEmptyState(message: 'No payments recorded.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: payments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (c, i) {
                  final p = payments[i];
                  final status = p['status'] as String;
                  final color = switch (status) {
                    'succeeded' => const Color(0xFF10B981),
                    'failed' => const Color(0xFFEF4444),
                    'pending' => const Color(0xFFF59E0B),
                    _ => const Color(0xFF6B7280),
                  };
                  return Card(child: ListTile(
                    title: Text('${(p['amount_cents'] as num? ?? 0) / 100} ${p['currency'] ?? 'USD'}'),
                    subtitle: Text(p['provider_reference'] as String? ?? ''),
                    trailing: AppBadge(label: status, color: color),
                  ));
                },
              ),
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(message: 'Failed to load payments', onRetry: () => ref.refresh(recentPaymentsProvider(profile.gymId).future)),
      ),
      floatingActionButton: isOwner ? FloatingActionButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refunds are processed via the Stripe dashboard'))) , child: const Icon(Icons.receipt_long)) : null,
    );
  }
}
