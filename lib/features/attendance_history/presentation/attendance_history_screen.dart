// lib/features/attendance_history/presentation/attendance_history_screen.dart
// Athletic Check-in Calendar & Attendance History (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';

final memberAttendanceHistoryProvider = FutureProvider.autoDispose.family<List<DateTime>, String>((ref, userId) async {
  final client = AppSupabase.client;

  // Resolve member_id
  final memberRows = await client
      .from('members')
      .select('id, gym_id')
      .eq('profile_id', userId)
      .limit(1);

  if ((memberRows as List).isEmpty) return [];

  final memberId = memberRows[0]['id'] as String;

  final res = await client
      .from('attendance')
      .select('check_in_at')
      .eq('member_id', memberId)
      .order('check_in_at', ascending: false);

  return (res as List)
      .map((row) => DateTime.parse(row['check_in_at'] as String))
      .toList();
});

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();

    final historyAsync = ref.watch(memberAttendanceHistoryProvider(profile.userId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ATTENDANCE LOG',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: historyAsync.when(
        data: (visits) {
          if (visits.isEmpty) {
            return const AppEmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'No Check-ins Yet',
              message: 'Scan the daily gym QR code at the front desk to log your workouts.',
            );
          }

          final now = DateTime.now();
          final thisMonthVisits = visits.where((v) => v.month == now.month && v.year == now.year).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Monthly Summary Stat Cards ──────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.dSurface : AppColors.lSurface,
                          borderRadius: AppRadii.card,
                          border: Border.all(color: cs.outline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THIS MONTH',
                              style: AppTypography.labelAthletic.copyWith(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$thisMonthVisits visits',
                              style: AppTypography.headlineLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.dSurface : AppColors.lSurface,
                          borderRadius: AppRadii.card,
                          border: Border.all(color: cs.outline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL VISITS',
                              style: AppTypography.labelAthletic.copyWith(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${visits.length} all time',
                              style: AppTypography.headlineLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── 2. Check-in Timeline ───────────────────────────────────────
                Text(
                  'RECENT CHECK-INS',
                  style: AppTypography.labelAthletic.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                ...visits.map((visit) {
                  final isToday = visit.year == now.year && visit.month == now.month && visit.day == now.day;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.dSurface : AppColors.lSurface,
                      borderRadius: AppRadii.card,
                      border: Border.all(
                        color: isToday
                            ? AppColors.brand.withAlpha(100)
                            : cs.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isToday
                                ? (isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer)
                                : (isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            color: isToday ? AppColors.brand : cs.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isToday ? 'Today' : DateFormat('EEEE, d MMMM yyyy').format(visit),
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('hh:mm a').format(visit),
                                style: AppTypography.bodySmall.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: AppTypography.labelAthletic.copyWith(
                                fontSize: 9,
                                color: isDark ? AppColors.brand : AppColors.brandDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(message: e.toString()),
      ),
    );
  }
}
