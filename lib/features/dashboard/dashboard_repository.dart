// lib/features/dashboard/dashboard_repository.dart
import '../../core/services/supabase_client.dart';

class DashboardStats {
  final int totalMembers;
  final int checkedInToday;
  final int redListOpen;
  final int renewalsDue;

  const DashboardStats({required this.totalMembers, required this.checkedInToday, required this.redListOpen, required this.renewalsDue});
}

abstract class DashboardRepository {
  Future<DashboardStats> fetchStats(String gymId);
}

class SupabaseDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardStats> fetchStats(String gymId) async {
    final client = AppSupabase.client;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final members = await client.from('members').select('id').eq('gym_id', gymId);
    final att = await client.from('attendance')
        .select('id').eq('gym_id', gymId)
        .gte('check_in_at', '${today}T00:00:00')
        .lt('check_in_at', '${today}T23:59:59');
    final red = await client.from('no_show_cases').select('id').eq('gym_id', gymId).eq('status', 'open');
    final ren = await client.from('renewal_orders').select('id').eq('gym_id', gymId).eq('status', 'pending');

    return DashboardStats(
      totalMembers: (members as List).length,
      checkedInToday: (att as List).length,
      redListOpen: (red as List).length,
      renewalsDue: (ren as List).length,
    );
  }
}
