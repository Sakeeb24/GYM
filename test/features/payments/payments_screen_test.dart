// test/features/payments/payments_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/payments/presentation/payments_screen.dart';

void main() {
  group('PaymentsScreen & Revenue Tests', () {
    const ownerProfile = Profile(
      userId: 'user-1',
      gymId: 'gym-1',
      username: 'coach_dave',
      role: AppRole.owner,
    );

    const memberProfile = Profile(
      userId: 'user-2',
      gymId: 'gym-1',
      username: 'alex_athlete',
      role: AppRole.member,
    );

    final fakePayments = [
      {
        'id': 'pay-1',
        'provider_reference': 'Pro Monthly Pass',
        'amount_cents': 4900,
        'currency': 'usd',
        'status': 'succeeded',
        'created_at': '2026-08-28T10:00:00Z',
      },
    ];

    testWidgets('Owner view renders revenue card and Stripe button with snackbar action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(ownerProfile)),
            recentPaymentsProvider((
              gymId: 'gym-1',
              role: AppRole.owner,
              userId: 'user-1',
            )).overrideWith((ref) => Stream.value(fakePayments)),
          ],
          child: const MaterialApp(
            home: PaymentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payments & Revenue'), findsOneWidget);
      expect(find.text('Monthly Revenue'), findsOneWidget);
      expect(find.text('₹49.00'), findsOneWidget);
      expect(find.text('Pro Monthly Pass'), findsOneWidget);
      expect(find.text('Stripe Portal'), findsOneWidget);

      // Tap Stripe Portal FAB
      await tester.tap(find.text('Stripe Portal'));
      await tester.pumpAndSettle();
      expect(find.text('Refunds are processed securely via the Stripe portal.'), findsOneWidget);
    });

    testWidgets('Member view renders invoices title without owner revenue banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(memberProfile)),
            recentPaymentsProvider((
              gymId: 'gym-1',
              role: AppRole.member,
              userId: 'user-2',
            )).overrideWith((ref) => Stream.value(fakePayments)),
          ],
          child: const MaterialApp(
            home: PaymentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payments & Invoices'), findsOneWidget);
      expect(find.text('Monthly Revenue'), findsNothing);
      expect(find.text('Payment History'), findsOneWidget);
      expect(find.text('Pro Monthly Pass'), findsOneWidget);
      expect(find.text('Stripe Portal'), findsNothing);
    });
  });
}
