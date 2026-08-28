// lib/features/renewals/presentation/renewals_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';

final pendingRenewalsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  final client = AppSupabase.client;
  return client.from('renewal_orders').stream(primaryKey: ['id']).eq('gym_id', gymId).eq('status', 'pending').map((r) => r);
});

class RenewalsScreen extends ConsumerWidget {
  const RenewalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final asyncOrders = ref.watch(pendingRenewalsProvider(profile.gymId));

    return Scaffold(
      appBar: AppBar(title: const Text('Renewals')),
      body: asyncOrders.when(
        data: (orders) => orders.isEmpty
            ? const AppEmptyState(message: 'No renewals due.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (c, i) {
                  final o = orders[i];
                  final due = DateTime.tryParse(o['due_at'] as String? ?? '');
                  return Card(child: ListTile(
                    title: Text(o['member_id'] as String),
                    subtitle: Text('Due ${due != null ? '${due.year}-${due.month}-${due.day}' : '—'} · ${(o['amount_cents'] as int? ?? 0) / 100}'),
                    trailing: AppBadge(label: o['reminder_stage'] ?? 'renew', color: const Color(0xFF0EA5E9)),
                  ));
                },
              ),
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(message: 'Failed to load renewals', onRetry: () => ref.refresh(pendingRenewalsProvider(profile.gymId).future)),
      ),
    );
  }
}

