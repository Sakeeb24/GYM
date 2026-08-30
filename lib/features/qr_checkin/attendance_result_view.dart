// lib/features/qr_checkin/attendance_result_view.dart
// Athletic Rewarding Check-in Outcome Display
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import 'attendance_repository.dart';

class AttendanceResultView extends StatelessWidget {
  final CheckInOutcome outcome;
  final String? memberName;
  final int streak;
  final VoidCallback? onDismiss;

  const AttendanceResultView({
    super.key,
    required this.outcome,
    this.memberName,
    this.streak = 1,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, color, title, subtitle) = _info(outcome);

    final isSuccess = outcome == CheckInOutcome.success;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: AppRadii.r16,
            border: Border.all(
              color: isSuccess
                  ? AppColors.success.withAlpha(90)
                  : (color ?? cs.outline),
              width: 1.5,
            ),
            boxShadow: isSuccess
                ? [
                    BoxShadow(
                      color: AppColors.success.withAlpha(30),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : (isDark ? AppShadows.cardElevation : AppShadows.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large Result Badge Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (color ?? cs.primary).withAlpha(24),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (color ?? cs.primary).withAlpha(80),
                    width: 2,
                  ),
                ),
                child: Icon(_icon(icon), size: 38, color: color ?? cs.primary),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title,
                style: AppTypography.headlineMedium.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),

              // Member Name (if provided)
              if (memberName != null && memberName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  memberName!.toUpperCase(),
                  style: AppTypography.labelAthletic.copyWith(
                    color: isDark ? AppColors.brand : AppColors.brandDark,
                    fontSize: 12,
                  ),
                ),
              ],

              // Success Motivational Quote & Flame Streak
              if (isSuccess) ...[
                const SizedBox(height: 10),
                Text(
                  '“Great workout. Keep the streak alive!”',
                  style: AppTypography.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.flameStreak.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.flameStreak.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: AppColors.flameStreak, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          streak > 1 ? 'CURRENT STREAK: $streak DAYS' : 'SESSION LOGGED: ACTIVE',
                          style: AppTypography.labelAthletic.copyWith(
                            color: AppColors.flameStreak,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Subtitle (for duplicate / denied / error)
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 28),

              // Action Button
              AppButton(
                text: isSuccess ? 'Done' : 'Try Again',
                variant: isSuccess ? AppButtonVariant.filled : AppButtonVariant.outlined,
                fullWidth: true,
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String icon, Color? color, String title, String subtitle) _info(CheckInOutcome outcome) {
    switch (outcome) {
      case CheckInOutcome.success:
        return ('check_circle', AppColors.success, 'CHECK-IN CONFIRMED', '');
      case CheckInOutcome.duplicate:
        return ('repeat', AppColors.warning, 'ALREADY CHECKED IN', 'Your attendance was already logged for this session.');
      case CheckInOutcome.denied:
        return ('block', AppColors.error, 'ACCESS DENIED', 'Your membership is inactive or expired. Please see front desk.');
      case CheckInOutcome.error:
        return ('error', AppColors.error, 'CHECK-IN ERROR', 'Unable to record check-in. Please try scanning again.');
      case CheckInOutcome.loading:
        return ('hourglass', null, 'VERIFYING PASS...', '');
    }
  }

  IconData _icon(String name) {
    switch (name) {
      case 'check_circle':
        return Icons.check_circle_rounded;
      case 'repeat':
        return Icons.cached_rounded;
      case 'block':
        return Icons.block_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}
