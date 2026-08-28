// lib/features/members/presentation/members_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/member.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';

final membersProvider = StreamProvider.autoDispose.family<List<Member>, String>((ref, gymId) {
  final client = AppSupabase.client;
  return client.from('members').stream(primaryKey: ['id']).eq('gym_id', gymId).map((rows) => rows.map(Member.fromMap).toList());
});

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final membersAsync = ref.watch(membersProvider(profile.gymId));

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: membersAsync.when(
        data: (members) => members.isEmpty
            ? const AppEmptyState(message: 'No members yet.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (c, i) => _MemberTile(member: members[i]),
              ),
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(message: 'Failed to load members', onRetry: () => ref.refresh(membersProvider(profile.gymId).future)),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Member member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: cs.primary.withAlpha(24), child: Text(member.memberNumber, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600))),
        title: Text(member.fullName),
        subtitle: Text(member.phone ?? member.email ?? 'No contact'),
        trailing: AppBadge(label: member.isActive ? 'Active' : 'Inactive', color: member.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
      ),
    );
  }
}

