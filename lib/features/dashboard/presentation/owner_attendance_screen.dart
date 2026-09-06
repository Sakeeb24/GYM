// lib/features/dashboard/presentation/owner_attendance_screen.dart
// Owner Attendance Management & Live Check-in Stream (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';

class AttendanceRecord {
  final String id;
  final String memberName;
  final String memberNumber;
  final DateTime checkInAt;
  final String source;

  AttendanceRecord({
    required this.id,
    required this.memberName,
    required this.memberNumber,
    required this.checkInAt,
    required this.source,
  });
}

final ownerAttendanceStreamProvider = StreamProvider.autoDispose.family<List<AttendanceRecord>, String>((ref, gymId) {
  final client = AppSupabase.client;

  return client
      .from('attendance')
      .stream(primaryKey: ['id'])
      .eq('gym_id', gymId)
      .order('check_in_at', ascending: false)
      .limit(50)
      .asyncMap((rows) async {
        if (rows.isEmpty) return [];

        final memberIds = rows.map((r) => r['member_id'] as String).toSet().toList();
        final memberRows = await client
            .from('members')
            .select('id, full_name, member_number')
            .inFilter('id', memberIds);

        final memberMap = {
          for (final m in (memberRows as List))
            m['id'] as String: {
              'full_name': m['full_name'] as String? ?? 'Athlete',
              'member_number': m['member_number'] as String? ?? '—',
            }
        };

        return rows.map((r) {
          final mId = r['member_id'] as String;
          final mInfo = memberMap[mId] ?? {'full_name': 'Athlete', 'member_number': '—'};

          return AttendanceRecord(
            id: r['id'] as String,
            memberName: mInfo['full_name']!,
            memberNumber: mInfo['member_number']!,
            checkInAt: DateTime.parse(r['check_in_at'] as String),
            source: (r['source'] as String?) ?? 'qr_self',
          );
        }).toList();
      });
});

class OwnerAttendanceScreen extends ConsumerWidget {
  const OwnerAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();

    final recordsAsync = ref.watch(ownerAttendanceStreamProvider(profile.gymId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ATTENDANCE ROSTER',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const AppEmptyState(
              icon: Icons.qr_code_scanner_rounded,
              title: 'No Check-ins Recorded Today',
              message: 'Check-ins will stream in real-time as athletes scan the gym QR pass.',
            );
          }

          final now = DateTime.now();
          final todayCount = records.where((r) => r.checkInAt.year == now.year && r.checkInAt.month == now.month && r.checkInAt.day == now.day).length;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: records.length + 1,
            itemBuilder: (ctx, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.dSurface : AppColors.lSurface,
                      borderRadius: AppRadii.card,
                      border: Border.all(color: cs.outline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TODAY'S CHECK-INS",
                              style: AppTypography.labelAthletic.copyWith(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$todayCount Athletes',
                              style: AppTypography.headlineLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LIVE STREAM',
                                style: AppTypography.labelAthletic.copyWith(
                                  fontSize: 9,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final record = records[index - 1];
              final isSelf = record.source == 'qr_self';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dSurface : AppColors.lSurface,
                  borderRadius: AppRadii.card,
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          record.memberName.isNotEmpty ? record.memberName[0].toUpperCase() : 'A',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.memberName,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: #${record.memberNumber} • ${DateFormat('hh:mm a').format(record.checkInAt)}',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppBadge.source(isSelf ? 'Self Scan' : 'Front Desk'),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(message: e.toString()),
      ),
    );
  }
}
