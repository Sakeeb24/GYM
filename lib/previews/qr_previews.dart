// lib/previews/qr_previews.dart
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../core/theme/app_theme.dart';
import '../features/qr_checkin/attendance_result_view.dart';
import '../features/qr_checkin/attendance_repository.dart';

Widget _wrapQr(Widget child, {bool isDark = true}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: isDark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: child,
        ),
      ),
    ),
  );
}

@Preview(name: 'Check-in Granted', group: 'QR Check-in')
Widget previewCheckInSuccess() => _wrapQr(
  AttendanceResultView(
    outcome: CheckInOutcome.success,
    memberName: 'Alex Johnson',
    onDismiss: () {},
  ),
);

@Preview(name: 'Check-in Duplicate (Already in)', group: 'QR Check-in')
Widget previewCheckInDuplicate() => _wrapQr(
  AttendanceResultView(
    outcome: CheckInOutcome.duplicate,
    memberName: 'Alex Johnson',
    onDismiss: () {},
  ),
);

@Preview(name: 'Check-in Denied (Inactive)', group: 'QR Check-in')
Widget previewCheckInDenied() => _wrapQr(
  AttendanceResultView(
    outcome: CheckInOutcome.denied,
    memberName: 'Alex Johnson',
    onDismiss: () {},
  ),
);
