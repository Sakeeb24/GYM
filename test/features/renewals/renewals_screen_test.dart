// test/features/renewals/renewals_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/renewals/presentation/renewals_screen.dart';

void main() {
  group('RenewalsScreen Widget Tests', () {
    const ownerProfile = Profile(
      userId: 'user-1',
      gymId: 'gym-1',
      username: 'coach_dave',
      fullName: 'Dave Miller',
      role: AppRole.owner,
    );

    final fakeOrders = [
      {
        'id': 'ord-1',
        'due_at': '2026-09-05T00:00:00Z',
        'amount_cents': 5000,
        'currency': 'INR',
        'reminder_stage': 'd_7',
        'status': 'pending',
      },
      {
        'id': 'ord-2',
        'due_at': '2026-09-01T00:00:00Z',
        'amount_cents': 9900,
        'currency': 'INR',
        'reminder_stage': 'd_3',
        'status': 'paid',
      },
    ];

    testWidgets('Renders renewals list with items, amounts, and badges', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            renewalsProvider((
              gymId: 'gym-1',
              role: AppRole.owner,
              userId: 'user-1',
            )).overrideWith((ref) => Stream.value(fakeOrders)),
          ],
          child: const MaterialApp(
            home: RenewalsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Renewals'), findsOneWidget);
      expect(find.text('Membership Renewal'), findsNWidgets(2));
      expect(find.text('₹50.00 INR'), findsOneWidget);
      expect(find.text('₹99.00 INR'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
    });

    testWidgets('Renders empty state when orders list is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            renewalsProvider((
              gymId: 'gym-1',
              role: AppRole.owner,
              userId: 'user-1',
            )).overrideWith((ref) => Stream.value(const [])),
          ],
          child: const MaterialApp(
            home: RenewalsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All athlete memberships are up to date! No pending renewals.'), findsOneWidget);
    });
  });
}
