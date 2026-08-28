// payment.dart
import 'package:flutter/foundation.dart';

/// Payment provider states. Success is ONLY set by the verified webhook.
enum PaymentStatus {
  created,
  pending,
  succeeded,
  failed,
  canceled,
  refunded,
  reversed,
}

@immutable
class Payment {
  final String id;
  final String providerReference;
  final String idempotencyKey;
  final int amountCents;
  final String currency;
  final PaymentStatus status;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.providerReference,
    required this.idempotencyKey,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.createdAt,
  });
}

/// R8. Terminal states after which no further state changes occur.
bool isPaymentTerminal(PaymentStatus s) =>
    s == PaymentStatus.succeeded ||
    s == PaymentStatus.canceled ||
    s == PaymentStatus.refunded ||
    s == PaymentStatus.reversed;

/// Allowed state transitions (rule 10: payment state machine).
bool isValidPaymentTransition(PaymentStatus from, PaymentStatus to) {
  if (from == to) return true;
  if (isPaymentTerminal(from)) return false;
  return switch ((from, to)) {
    (PaymentStatus.created, PaymentStatus.pending) => true,
    (PaymentStatus.pending, PaymentStatus.succeeded) => true,
    (PaymentStatus.pending, PaymentStatus.failed) => true,
    (PaymentStatus.pending, PaymentStatus.canceled) => true,
    (PaymentStatus.succeeded, PaymentStatus.refunded) => true,
    (PaymentStatus.succeeded, PaymentStatus.reversed) => true,
    _ => false,
  };
}

/// Idempotent application of a provider event. Returns `null` if the event is
/// a duplicate (already processed) or invalid.
Payment? applyPaymentEvent(
  Payment? current,
  String providerReference,
  PaymentStatus newState,
) {
  if (current != null) {
    if (current.providerReference == providerReference &&
        isPaymentTerminal(current.status)) {
      return null; // duplicate final state
    }
    if (!isValidPaymentTransition(current.status, newState)) return null;
  }
  return Payment(
    id: current?.id ?? '',
    providerReference: providerReference,
    idempotencyKey: current?.idempotencyKey ?? providerReference,
    amountCents: current?.amountCents ?? 0,
    currency: current?.currency ?? 'USD',
    status: newState,
    createdAt: current?.createdAt ?? DateTime.now(),
  );
}
