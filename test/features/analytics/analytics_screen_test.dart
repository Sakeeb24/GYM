// test/features/analytics/analytics_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/features/analytics/presentation/analytics_screen.dart';

void main() {
  group('AnalyticsScreen Widget Tests', () {
    testWidgets('Renders attendance metrics, volume bars, and traffic breakdown', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AnalyticsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights & Attendance'), findsOneWidget);
      expect(find.text("Today's Attendance"), findsOneWidget);
      expect(find.text('186 Check-ins'), findsOneWidget);
      expect(find.text('Retention Rate'), findsOneWidget);
      expect(find.text('Active Streaks'), findsOneWidget);
      expect(find.text('Weekly Volume'), findsOneWidget);
      expect(find.text('Peak Floor Traffic'), findsOneWidget);
      expect(find.textContaining('Morning Rush'), findsOneWidget);
      expect(find.textContaining('Peak Evening'), findsOneWidget);
    });
  });
}
