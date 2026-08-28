// lib/features/qr_checkin/attendance_result_view.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'attendance_repository.dart';

/// Pure, camera-free UI for the outcome of a check-in attempt. Fully testable.
class AttendanceResultView extends StatelessWidget {
  final CheckInOutcome outcome;
  final String? memberName;
  final VoidCallback? onDismiss;

  const AttendanceResultView({super.key, required this.outcome, this.memberName, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color, title, subtitle) = _info(outcome);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 28, backgroundColor: (color ?? cs.primary).withAlpha(24), child: Icon(_icon(icon), size: 32, color: color ?? cs.primary)),
              const SizedBox(height: 14),
              Text(title, style: AppTypography.headlineSmall.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              if (subtitle.isNotEmpty) ...[const SizedBox(height: 6), Text(subtitle, style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center)],
              if (onDismiss != null) ...[const SizedBox(height: 16), TextButton(onPressed: onDismiss, child: const Text('Back to scan'))],
            ]),
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

(String, Color?, String, String) _info(CheckInOutcome o) =>
    switch (o) {
      CheckInOutcome.success => ('check_circle', AppColors.success, 'Check-in recorded', ''),
      CheckInOutcome.duplicate => ('sync', AppColors.warning, 'Already in', 'This QR was scanned recently.'),
      CheckInOutcome.denied => ('cancel', AppColors.error, 'Check-in denied', 'Membership inactive. See a staff member.'),
      CheckInOutcome.error => ('error', AppColors.error, 'Something went wrong', 'Try again or see a staff member.'),
      CheckInOutcome.loading => ('hourglass_empty', null, 'Scanning…', ''),
    };
