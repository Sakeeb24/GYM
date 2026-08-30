// test/features/qr_checkin/qr_checkin_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/features/qr_checkin/attendance_repository.dart';
import 'package:liftflow/features/qr_checkin/attendance_result_view.dart';
import 'package:liftflow/features/qr_checkin/qr_scanner_view.dart';

void main() {
  group('QR Check-in & Scanner Views', () {
    testWidgets('QrScannerView renders HUD frame and triggers onDetected on simulate button tap', (tester) async {
      String? detectedPayload;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrScannerView(
              onDetected: (payload) => detectedPayload = payload,
              simulating: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ALIGN QR CODE WITHIN FRAME'), findsOneWidget);
      expect(find.text('SIMULATE SCAN (DEV)'), findsOneWidget);

      await tester.tap(find.text('SIMULATE SCAN (DEV)'));
      await tester.pumpAndSettle();

      expect(detectedPayload, isNotNull);
      expect(detectedPayload, contains('00000000-0000-0000-0000-00000000000A'));
    });

    testWidgets('AttendanceResultView handles dismiss callback on Back to scan button', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceResultView(
              outcome: CheckInOutcome.success,
              memberName: 'Alex Athlete',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Check-in recorded'), findsOneWidget);
      expect(find.text('ALEX ATHLETE'), findsOneWidget);
      expect(find.text('Back to scan'), findsOneWidget);

      await tester.tap(find.text('Back to scan'));
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });
}
