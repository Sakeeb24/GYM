// lib/features/analytics/presentation/analytics_screen.dart
// Clean Gym Performance Insights & Attendance Trends (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';

class DailyCheckInStat {
  final String date;
  final int count;

  const DailyCheckInStat({required this.date, required this.count});
}

class AnalyticsData {
  final int totalCheckins;
  final int activeMembers;
  final double retentionRate;
  final List<DailyCheckInStat> dailyTrend;
  final List<Map<String, dynamic>> hourlyDistribution;

  const AnalyticsData({
    required this.totalCheckins,
    required this.activeMembers,
    required this.retentionRate,
    required this.dailyTrend,
    required this.hourlyDistribution,
  });

  factory AnalyticsData.fromMap(Map<String, dynamic> map) {
    final rawDaily = map['daily_trend'];
    final List<DailyCheckInStat> daily = [];
    if (rawDaily is List) {
      for (final item in rawDaily) {
        if (item is Map) {
          daily.add(DailyCheckInStat(
            date: item['check_date']?.toString() ?? '',
            count: (item['count'] as num?)?.toInt() ?? 0,
          ));
        }
      }
    }

    final rawHourly = map['hourly_distribution'];
    final List<Map<String, dynamic>> hourly = [];
    if (rawHourly is List) {
      for (final item in rawHourly) {
        if (item is Map) {
          hourly.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return AnalyticsData(
      totalCheckins: (map['total_checkins'] as num?)?.toInt() ?? 0,
      activeMembers: (map['active_members'] as num?)?.toInt() ?? 0,
      retentionRate: (map['retention_rate'] as num?)?.toDouble() ?? 100.0,
      dailyTrend: daily,
      hourlyDistribution: hourly,
    );
  }

  factory AnalyticsData.empty() {
    return const AnalyticsData(
      totalCheckins: 0,
      activeMembers: 0,
      retentionRate: 100.0,
      dailyTrend: [],
      hourlyDistribution: [],
    );
  }
}

final analyticsProvider = FutureProvider.family<AnalyticsData, (String, int)>((ref, params) async {
  final (gymId, days) = params;
  final client = AppSupabase.client;

  try {
    final res = await client.rpc('get_analytics_trends', params: {
      'p_gym_id': gymId,
      'p_days': days,
    });
    if (res != null && res is Map) {
      return AnalyticsData.fromMap(Map<String, dynamic>.from(res));
    }
  } catch (_) {
    // Fallback if RPC is not available
  }

  return AnalyticsData.empty();
});

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedDays = 30;

  String _formatPeakHours(List<Map<String, dynamic>> hourly) {
    if (hourly.isEmpty) return 'Standard: 6 AM — 9 PM';
    final sorted = [...hourly]..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0).compareTo((a['count'] as num?)?.toInt() ?? 0));
    final topHour = (sorted.first['hour'] as num?)?.toInt() ?? 18;
    final topEnd = (topHour + 2) % 24;
    final ampm1 = topHour >= 12 ? 'PM' : 'AM';
    final ampm2 = topEnd >= 12 ? 'PM' : 'AM';
    final h1 = topHour > 12 ? topHour - 12 : (topHour == 0 ? 12 : topHour);
    final h2 = topEnd > 12 ? topEnd - 12 : (topEnd == 0 ? 12 : topEnd);
    return 'Peak: $h1 $ampm1 — $h2 $ampm2';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analyticsAsync = ref.watch(analyticsProvider((profile.gymId, _selectedDays)));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Insights & Attendance',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: analyticsAsync.when(
        data: (data) {
          final peakHours = _formatPeakHours(data.hourlyDistribution);
          final avgDaily = _selectedDays > 0 ? (data.totalCheckins / _selectedDays).toStringAsFixed(1) : '0';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date Range Selector ──────────────────────────────
                Row(
                  children: [
                    _TimeFilterChip(
                      label: '7 Days',
                      selected: _selectedDays == 7,
                      onTap: () => setState(() => _selectedDays = 7),
                    ),
                    const SizedBox(width: 8),
                    _TimeFilterChip(
                      label: '30 Days',
                      selected: _selectedDays == 30,
                      onTap: () => setState(() => _selectedDays = 30),
                    ),
                    const SizedBox(width: 8),
                    _TimeFilterChip(
                      label: '90 Days',
                      selected: _selectedDays == 90,
                      onTap: () => setState(() => _selectedDays = 90),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 1. Attendance Overview ───────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: AppRadii.r12,
                    border: Border.all(color: cs.outline),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Attendance Volume ($_selectedDays days)',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            peakHours,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.flameStreak,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${data.totalCheckins} Check-ins',
                        style: AppTypography.metricLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Avg. $avgDaily visits/day across ${data.activeMembers} active athletes',
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 2. Metric Grid ──────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        data: StatCardData(
                          title: 'Retention Rate',
                          value: '${data.retentionRate.toStringAsFixed(1)}%',
                          subtitle: 'Active vs churned',
                          icon: const Icon(Icons.verified_user_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        data: StatCardData(
                          title: 'Active Athletes',
                          value: '${data.activeMembers}',
                          subtitle: 'Enrolled in gym',
                          icon: const Icon(Icons.groups_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── 3. Daily Attendance Trend ────────────────────────
                Text(
                  'Daily Check-in Activity',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                if (data.dailyTrend.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: AppRadii.r12,
                      border: Border.all(color: cs.outline),
                    ),
                    child: const Center(
                      child: Text('No check-in trends recorded in this time range.'),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: AppRadii.r12,
                      border: Border.all(color: cs.outline),
                    ),
                    child: Column(
                      children: data.dailyTrend.take(10).map((day) {
                        final maxVal = data.dailyTrend.fold<int>(1, (max, d) => d.count > max ? d.count : max);
                        final progress = (day.count / maxVal).clamp(0.05, 1.0);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 85,
                                child: Text(
                                  day.date,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 14,
                                    backgroundColor: cs.outline.withAlpha(50),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? AppColors.brand : AppColors.brandDark,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${day.count}',
                                  textAlign: TextAlign.end,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load gym analytics',
          onRetry: () => ref.refresh(analyticsProvider((profile.gymId, _selectedDays)).future),
        ),
      ),
    );
  }
}

class _TimeFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
      side: BorderSide(
        color: selected
            ? (isDark ? AppColors.brand : AppColors.brandDark)
            : cs.outline,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
