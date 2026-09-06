// test/features/payments/razorpay_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';

void main() {
  group('Razorpay Payment Flow & Webhook Invariant Tests', () {
    final t0 = DateTime(2026, 9, 1, 10, 0, 0);

    test('Valid lifecycle: created -> pending -> succeeded', () {
      expect(isValidPaymentTransition(PaymentStatus.created, PaymentStatus.pending), isTrue);
      expect(isValidPaymentTransition(PaymentStatus.pending, PaymentStatus.succeeded), isTrue);
    });

    test('Valid failure lifecycle: created -> pending -> failed', () {
      expect(isValidPaymentTransition(PaymentStatus.pending, PaymentStatus.failed), isTrue);
    });

    test('Terminal state rejection: succeeded cannot transition to failed or canceled', () {
      expect(isValidPaymentTransition(PaymentStatus.succeeded, PaymentStatus.failed), isFalse);
      expect(isValidPaymentTransition(PaymentStatus.succeeded, PaymentStatus.canceled), isFalse);
    });

    test('Idempotent webhook deduplication: duplicate succeeded event returns null (no duplicate credit)', () {
      final existingPayment = Payment(
        id: 'pay_123',
        providerReference: 'order_rzp_999',
        idempotencyKey: 'order_rzp_999',
        amountCents: 199900,
        currency: 'INR',
        status: PaymentStatus.succeeded,
        createdAt: t0,
      );

      final result = applyPaymentEvent(existingPayment, 'order_rzp_999', PaymentStatus.succeeded);
      expect(result, isNull, reason: 'Duplicate delivery must be ignored idempotently');
    });

    test('First delivery applies status update atomically', () {
      final pendingPayment = Payment(
        id: 'pay_123',
        providerReference: 'order_rzp_999',
        idempotencyKey: 'order_rzp_999',
        amountCents: 199900,
        currency: 'INR',
        status: PaymentStatus.pending,
        createdAt: t0,
      );

      final updated = applyPaymentEvent(pendingPayment, 'order_rzp_999', PaymentStatus.succeeded);
      expect(updated, isNotNull);
      expect(updated!.status, equals(PaymentStatus.succeeded));
    });
  });
}
