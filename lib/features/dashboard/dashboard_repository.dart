// lib/features/dashboard/dashboard_repository.dart
import '../../core/services/supabase_client.dart';

class RecentActivityItem {
  final String id;
  final DateTime checkInAt;
  final String source;
  final String memberName;
  final String memberNumber;

  const RecentActivityItem({
    required this.id,
    required this.checkInAt,
    required this.source,
    required this.memberName,
    required this.memberNumber,
  });

  factory RecentActivityItem.fromMap(Map<String, dynamic> map) {
    return RecentActivityItem(
      id: map['id']?.toString() ?? '',
      checkInAt: DateTime.tryParse(map['check_in_at']?.toString() ?? '') ?? DateTime.now(),
      source: map['source']?.toString() ?? 'qr_self',
      memberName: map['member_name']?.toString() ?? 'Athlete',
      memberNumber: map['member_number']?.toString() ?? '—',
    );
  }
}

class DashboardStats {
  final int totalMembers;
  final int checkedInToday;
  final int expiringMembers;
  final int redListOpen;
  final int renewalsDue;
  final int monthlyRevenueCents;
  final List<RecentActivityItem> recentActivity;

  const DashboardStats({
    required this.totalMembers,
    required this.checkedInToday,
    required this.expiringMembers,
    required this.redListOpen,
    required this.renewalsDue,
    required this.monthlyRevenueCents,
    required this.recentActivity,
  });

  factory DashboardStats.empty() {
    return const DashboardStats(
      totalMembers: 0,
      checkedInToday: 0,
      expiringMembers: 0,
      redListOpen: 0,
      renewalsDue: 0,
      monthlyRevenueCents: 0,
      recentActivity: [],
    );
  }
}

abstract class DashboardRepository {
  Future<DashboardStats> fetchStats(String gymId);
}

class SupabaseDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardStats> fetchStats(String gymId) async {
    final client = AppSupabase.client;

    try {
      // 1. Prefer single-roundtrip performant RPC
      final rpcRes = await client.rpc('get_dashboard_stats', params: {'p_gym_id': gymId});
      if (rpcRes != null && rpcRes is Map) {
        final data = Map<String, dynamic>.from(rpcRes);
        final rawActivity = data['recent_activity'];
        final List<RecentActivityItem> activity = [];
        if (rawActivity is List) {
          for (final item in rawActivity) {
            if (item is Map) {
              activity.add(RecentActivityItem.fromMap(Map<String, dynamic>.from(item)));
            }
          }
        }

        return DashboardStats(
          totalMembers: (data['total_members'] as num?)?.toInt() ?? 0,
          checkedInToday: (data['checked_in_today'] as num?)?.toInt() ?? 0,
          expiringMembers: (data['expiring_members'] as num?)?.toInt() ?? 0,
          redListOpen: (data['red_list_count'] as num?)?.toInt() ?? 0,
          renewalsDue: (data['renewals_due'] as num?)?.toInt() ?? 0,
          monthlyRevenueCents: (data['monthly_revenue_cents'] as num?)?.toInt() ?? 0,
          recentActivity: activity,
        );
      }
    } catch (_) {
      // Fallback query logic if RPC is unavailable
    }

    // Fallback: direct table queries
    final nowUtc = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final startOfMonth = DateTime.utc(nowUtc.year, nowUtc.month, 1);

    final members = await client
        .from('members')
        .select('id')
        .eq('gym_id', gymId)
        .eq('status', 'active');

    final att = await client
        .from('attendance')
        .select('id, check_in_at, source, member_id, members(full_name, member_number)')
        .eq('gym_id', gymId)
        .gte('check_in_at', startOfDay.toIso8601String())
        .order('check_in_at', ascending: false);

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

    final payments = await client
        .from('payments')
        .select('amount_cents')
        .eq('gym_id', gymId)
        .eq('status', 'succeeded')
        .gte('created_at', startOfMonth.toIso8601String());

    int revenueCents = 0;
    for (final p in payments) {
      revenueCents += (p['amount_cents'] as num?)?.toInt() ?? 0;
    }

    final List<RecentActivityItem> activity = [];
    for (final row in att.take(5)) {
      final mem = row['members'];
      String name = 'Athlete';
      String num = '—';
      if (mem is Map) {
        name = mem['full_name']?.toString() ?? 'Athlete';
        num = mem['member_number']?.toString() ?? '—';
      }
      activity.add(RecentActivityItem(
        id: row['id']?.toString() ?? '',
        checkInAt: DateTime.tryParse(row['check_in_at']?.toString() ?? '') ?? DateTime.now(),
        source: row['source']?.toString() ?? 'qr_self',
        memberName: name,
        memberNumber: num,
      ));
    }

    return DashboardStats(
      totalMembers: (members as List).length,
      checkedInToday: (att as List).length,
      expiringMembers: 0,
      redListOpen: (red as List).length,
      renewalsDue: (ren as List).length,
      monthlyRevenueCents: revenueCents,
      recentActivity: activity,
    );
  }
}
