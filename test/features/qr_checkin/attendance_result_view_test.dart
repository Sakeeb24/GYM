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
            streak: 5,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    expect(find.text('CHECK-IN CONFIRMED'), findsOneWidget);
    expect(find.text('CURRENT STREAK: 5 DAYS'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text('Done'));
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

    expect(find.text('ACCESS DENIED'), findsOneWidget);
    expect(find.text('Your membership is inactive or expired. Please see front desk.'), findsOneWidget);
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

    expect(find.text('ALREADY CHECKED IN'), findsOneWidget);
    expect(find.text('Your attendance was already logged for this session.'), findsOneWidget);
  });
}
