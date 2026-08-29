// test/features/qr_checkin/attendance_result_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/features/qr_checkin/attendance_repository.dart';
import 'package:liftflow/features/qr_checkin/attendance_result_view.dart';

void main() {
  testWidgets('AttendanceResultView shows success outcome', (tester) async {
    bool dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttendanceResultView(
            outcome: CheckInOutcome.success,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    expect(find.text('Check-in recorded'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Back to scan'));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('AttendanceResultView shows denied outcome', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttendanceResultView(
            outcome: CheckInOutcome.denied,
          ),
        ),
      ),
    );

    expect(find.text('Check-in denied'), findsOneWidget);
    expect(find.text('Membership inactive. See a staff member.'), findsOneWidget);
  });

  testWidgets('AttendanceResultView shows duplicate outcome', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttendanceResultView(
            outcome: CheckInOutcome.duplicate,
          ),
        ),
      ),
    );

    expect(find.text('Already in'), findsOneWidget);
    expect(find.text('This QR was scanned recently.'), findsOneWidget);
  });
}
