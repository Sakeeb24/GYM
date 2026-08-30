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
  Stream<List<NoShowCase>> openCases(String gymId) async* {
    final client = AppSupabase.client;

    Future<List<NoShowCase>> fetch() async {
      try {
        final rows = await client
            .from('no_show_cases')
            .select('id, member_id, gym_id, status, reason, last_seen_at, created_at, resolved_outcome, resolved_at, members(full_name)')
            .eq('gym_id', gymId)
            .eq('status', 'open')
            .order('created_at', ascending: false);

        return (rows as List).map((r) {
          final memberObj = r['members'];
          final memberName = memberObj is Map ? (memberObj['full_name'] as String? ?? 'Member') : 'Member';
          return NoShowCase(
            id: r['id'] as String,
            memberId: r['member_id'] as String,
            memberName: memberName,
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
          );
        }).toList();
      } catch (_) {
        return [];
      }
    }

    yield await fetch();

    try {
      await for (final _ in client.from('no_show_cases').stream(primaryKey: ['id']).eq('gym_id', gymId)) {
        yield await fetch();
      }
    } catch (_) {
      // Fallback to initial yield if realtime stream is unavailable
    }
  }

  @override
  Future<void> resolveCase(String caseId, String status, String outcome) async {
    await AppSupabase.client.from('no_show_cases').update({
      'status': status,
      'resolved_outcome': outcome,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', caseId);
  }
}

final openCasesProvider = StreamProvider.family<List<NoShowCase>, String>((ref, gymId) {
  return ref.watch(noShowRepositoryProvider).openCases(gymId);
});
