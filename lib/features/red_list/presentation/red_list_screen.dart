// lib/features/red_list/presentation/red_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Red List')),
      body: asyncCases.when(
        data: (cases) => cases.isEmpty
            ? const AppEmptyState(message: 'No members on the red list.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: cases.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (c, i) => Dismissible(
                  key: ValueKey(cases[i].id),
                  background: Container(
                    color: Colors.green.withAlpha(40),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.check, color: Colors.green),
                  ),
                  onDismissed: (direction) async {
                    await ref.read(noShowRepositoryProvider).resolveCase(cases[i].id, 'resolved', 'returned');
                  },
                  child: _CaseTile(caseItem: cases[i]),
                ),
              ),
        loading: () => const AppLoadingState(),
        error: (e, stack) => AppErrorState(
          message: 'Failed to load red list',
          onRetry: () {
            ref.invalidate(openCasesProvider(profile.gymId));
          },
        ),
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  final NoShowCase caseItem;
  const _CaseTile({required this.caseItem});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.error.withAlpha(24),
          child: const Icon(Icons.warning_amber, color: Colors.red),
        ),
        title: Text(caseItem.memberName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${caseItem.reason} • opened ${_formatDate(caseItem.createdAt)}'),
        trailing: AppBadge(label: caseItem.status, color: _statusColor(caseItem.status)),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'open' => const Color(0xFFEF4444),
    'resolved' => const Color(0xFF10B981),
    _ => const Color(0xFFF59E0B),
  };

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
