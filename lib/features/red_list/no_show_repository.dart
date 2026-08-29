// lib/features/red_list/no_show_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_client.dart';
import '../../core/models/no_show_case.dart';

final noShowRepositoryProvider = Provider<NoShowRepository>((ref) => SupabaseNoShowRepository());

abstract class NoShowRepository {
  Stream<List<NoShowCase>> openCases(String gymId);
  Future<void> resolveCase(String caseId, String status, String outcome);
}

class SupabaseNoShowRepository implements NoShowRepository {
  @override
  Stream<List<NoShowCase>> openCases(String gymId) {
    final client = AppSupabase.client;
    return client
        .from('no_show_cases')
        .stream(primaryKey: ['id'])
        .eq('gym_id', gymId)
        .eq('status', 'open')
        .map(
          (rows) => rows
              .map(
                (r) => NoShowCase(
                  id: r['id'] as String,
                  memberId: r['member_id'] as String,
                  memberName: r['member_name'] as String? ?? '—',
                  gymId: r['gym_id'] as String,
                  status: r['status'] as String,
                  reason: r['reason'] as String? ?? '',
                  createdAt: DateTime.parse(r['created_at'] as String),
                  lastSeenAt: r['last_seen_at'] == null
                      ? null
                      : DateTime.parse(r['last_seen_at'] as String),
                  resolvedOutcome: r['resolved_outcome'] as String?,
                  resolvedAt: r['resolved_at'] == null
                      ? null
                      : DateTime.parse(r['resolved_at'] as String),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> resolveCase(String caseId, String status, String outcome) async {
    await AppSupabase.client.from('no_show_cases').update({
      'status': status,
      'resolved_outcome': outcome,
      'resolved_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', caseId);
  }
}

final openCasesProvider = StreamProvider.family<List<NoShowCase>, String>((ref, gymId) {
  return ref.watch(noShowRepositoryProvider).openCases(gymId);
});
