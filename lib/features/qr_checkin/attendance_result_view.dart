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
  final VoidCallback? onDismiss;

  const AttendanceResultView({
    super.key,
    required this.outcome,
    this.memberName,
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
                          'CURRENT STREAK: 24 DAYS',
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
                  style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // Dismiss / Back to scan CTA
              if (onDismiss != null)
                AppButton(
                  text: 'Back to scan',
                  onPressed: onDismiss,
                  fullWidth: true,
                  variant: isSuccess ? AppButtonVariant.filled : AppButtonVariant.outlined,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _icon(String name) => switch (name) {
      'check_circle' => Icons.check_circle,
      'sync' => Icons.sync,
      'cancel' => Icons.cancel,
      'error' => Icons.error,
      'hourglass_empty' => Icons.hourglass_empty,
      _ => Icons.info,
    };

(String, Color?, String, String) _info(CheckInOutcome o) => switch (o) {
      CheckInOutcome.success => ('check_circle', AppColors.success, 'Check-in recorded', ''),
      CheckInOutcome.duplicate => ('sync', AppColors.warning, 'Already in', 'This QR was scanned recently.'),
      CheckInOutcome.denied => ('cancel', AppColors.error, 'Check-in denied', 'Membership inactive. See a staff member.'),
      CheckInOutcome.error => ('error', AppColors.error, 'Something went wrong', 'Try again or see a staff member.'),
      CheckInOutcome.loading => ('hourglass_empty', null, 'Scanning…', ''),
    };
