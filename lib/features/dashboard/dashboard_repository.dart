// lib/features/dashboard/dashboard_repository.dart
import '../../core/services/supabase_client.dart';

class DashboardStats {
  final int totalMembers;
  final int checkedInToday;
  final int redListOpen;
  final int renewalsDue;

  const DashboardStats({
    required this.totalMembers,
    required this.checkedInToday,
    required this.redListOpen,
    required this.renewalsDue,
  });
}

abstract class DashboardRepository {
  Future<DashboardStats> fetchStats(String gymId);
}

class SupabaseDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardStats> fetchStats(String gymId) async {
    final client = AppSupabase.client;

    // Use UTC calendar-day boundaries [startOfDay, nextStartOfDay)
    final nowUtc = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final nextStartOfDay = startOfDay.add(const Duration(days: 1));

    final startIso = startOfDay.toIso8601String();
    final nextStartIso = nextStartOfDay.toIso8601String();

    final members = await client
        .from('members')
        .select('id')
        .eq('gym_id', gymId)
        .eq('status', 'active');

    final att = await client
        .from('attendance')
        .select('id')
        .eq('gym_id', gymId)
        .gte('check_in_at', startIso)
        .lt('check_in_at', nextStartIso);

    final red = await client
        .from('no_show_cases')
        .select('id')
        .eq('gym_id', gymId)
        .eq('status', 'open');

    final ren = await client
        .from('renewal_orders')
        .select('id')
        .eq('gym_id', gymId)
        .eq('status', 'pending');

    return DashboardStats(
      totalMembers: (members as List).length,
      checkedInToday: (att as List).length,
      redListOpen: (red as List).length,
      renewalsDue: (ren as List).length,
    );
  }
}
