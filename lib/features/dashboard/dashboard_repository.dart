// lib/features/dashboard/dashboard_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
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
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final members = await client.from('members').select('id').eq('gym_id', gymId);
    final att = await client.from('attendance')
        .select('id').eq('gym_id', gymId)
        .gte('check_in_at', '$todayT00:00:00').lt('check_in_at', '$todayT23:59:59');
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
