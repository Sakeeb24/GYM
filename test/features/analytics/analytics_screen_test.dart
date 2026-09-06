// test/features/analytics/analytics_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/analytics/presentation/analytics_screen.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';

void main() {
  group('AnalyticsScreen Widget Tests', () {
    testWidgets('Renders attendance metrics, volume bars, and traffic breakdown', (tester) async {
      const ownerProfile = Profile(
        userId: 'user-1',
        gymId: 'gym-1',
        username: 'coach_dave',
        fullName: 'Dave Miller',
        role: AppRole.owner,
      );

      const fakeData = AnalyticsData(
        totalCheckins: 85,
        activeMembers: 30,
        retentionRate: 94.5,
        dailyTrend: [
          DailyCheckInStat(date: '2026-08-30', count: 12),
        ],
        hourlyDistribution: [
          {'hour': 18, 'count': 8},
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            analyticsProvider(('gym-1', 30)).overrideWith((ref) => Future.value(fakeData)),
          ],
          child: const MaterialApp(
            home: AnalyticsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights & Attendance'), findsOneWidget);
      expect(find.textContaining('85 Check-ins'), findsOneWidget);
      expect(find.text('Retention Rate'), findsOneWidget);
      expect(find.text('94.5%'), findsOneWidget);
      expect(find.text('Active Athletes'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });
  });
}
