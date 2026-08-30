// test/features/dashboard/dashboard_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/dashboard/dashboard_repository.dart';
import 'package:liftflow/features/dashboard/presentation/owner_dashboard_screen.dart';
import 'package:liftflow/features/dashboard/presentation/member_dashboard_screen.dart';

void main() {
  group('Dashboard Screens & Button Interactions', () {
    testWidgets('OwnerDashboardScreen renders greeting, hero card, metrics, and quick action buttons', (tester) async {
      const ownerProfile = Profile(
        userId: 'user-123',
        gymId: 'gym-456',
        username: 'coach_dave',
        fullName: 'Dave Miller',
        role: AppRole.owner,
      );

      const fakeStats = DashboardStats(
        totalMembers: 120,
        checkedInToday: 45,
        redListOpen: 3,
        renewalsDue: 8,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            dashboardStatsProvider('gym-456').overrideWith((ref) => Future.value(fakeStats)),
          ],
          child: const MaterialApp(
            home: OwnerDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Greeting & Header
      expect(find.textContaining('Dave Miller'), findsOneWidget);
      expect(find.text("Ready for today's workout?"), findsOneWidget);

      // Verify Attendance Card
      expect(find.text('Attendance'), findsOneWidget);

      // Verify Metric Grid Cards
      expect(find.text('Active Members'), findsOneWidget);
      expect(find.text("Today's Check-ins"), findsOneWidget);
      expect(find.text('Expiring Soon'), findsOneWidget);
      expect(find.text('Monthly Revenue'), findsOneWidget);

      // Verify Quick Action Buttons
      final memberBtn = find.text('+ Member');
      expect(memberBtn, findsOneWidget);
      await tester.ensureVisible(memberBtn);
      await tester.tap(memberBtn);
      await tester.pumpAndSettle();
      expect(find.text('Member pre-registration is managed in the Members tab.'), findsOneWidget);

      // Clear previous snackbar before next tap
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final scanBtn = find.text('Scan QR');
      expect(scanBtn, findsOneWidget);
      await tester.ensureVisible(scanBtn);
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();
      expect(find.text('Switch to Check-in tab to scan passes.'), findsOneWidget);
    });

    testWidgets('MemberDashboardScreen renders digital pass and check-in button', (tester) async {
      const memberProfile = Profile(
        userId: 'member-999',
        gymId: 'gym-456',
        username: 'alex_athlete',
        fullName: 'Alex Johnson',
        role: AppRole.member,
      );

      final fakeMemberData = MemberDashboardData(
        currentStreak: 14,
        longestStreak: 21,
        totalVisits: 38,
        membershipStatus: MembershipStatus.active,
        expiresAt: DateTime(2026, 12, 31),
        planName: 'Elite Annual Plan',
        memberNumber: '1084',
        recentVisits: [DateTime(2026, 8, 29, 9, 30)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(memberProfile)),
            memberDashboardProvider('member-999').overrideWith((ref) => Future.value(fakeMemberData)),
          ],
          child: const MaterialApp(
            home: MemberDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Pass Card
      expect(find.text('LIFTFLOW PASS'), findsOneWidget);
      expect(find.text('Alex Johnson'), findsOneWidget);
      expect(find.text('Elite Annual Plan'), findsOneWidget);
      expect(find.text('1084'), findsOneWidget);

      // Verify Streak & Sessions
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('14 days'), findsOneWidget);
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);

      // Verify CTA Button
      expect(find.text('Scan QR to Check In'), findsOneWidget);
    });
  });
}
