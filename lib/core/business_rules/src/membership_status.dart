import 'package:flutter/foundation.dart';
import 'clock.dart';

/// Membership lifecycle states. The *stored* DB column is one of
/// {active, paused, frozen, expired, canceled}; the computed live set adds
/// `expiring` (transient, for renewal reminders) and `inactive`.
enum MembershipStatus {
  active,
  paused,
  frozen,
  expired,
  canceled,
  expiring,
  inactive,
}

/// Billing interval for a membership plan.
enum BillingInterval { oneTime, monthly, annual }

/// A pricing plan. Duration drives the membership-extension (rule R8).
@immutable
class Plan {
  final int durationDays;
  final int gracePeriodDays;
  final BillingInterval billingInterval;

  const Plan({
    required this.durationDays,
    this.gracePeriodDays = 3,
    this.billingInterval = BillingInterval.oneTime,
  });
}

/// In-memory membership model (mirrors the memberships row).
@immutable
class Membership {
  final String id;
  final String memberId;
  final String gymId;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final DateTime? pausedAt;
  final DateTime? pausedUntil;
  final DateTime? canceledAt;

  const Membership({
    required this.id,
    required this.memberId,
    required this.gymId,
    required this.startedAt,
    this.expiresAt,
    this.pausedAt,
    this.pausedUntil,
    this.canceledAt,
  });

  Membership copyWith({
    String? id,
    String? memberId,
    String? gymId,
    DateTime? startedAt,
    DateTime? expiresAt,
    DateTime? pausedAt,
    DateTime? pausedUntil,
    DateTime? canceledAt,
  }) =>
      Membership(
        id: id ?? this.id,
        memberId: memberId ?? this.memberId,
        gymId: gymId ?? this.gymId,
        startedAt: startedAt ?? this.startedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        pausedAt: pausedAt ?? this.pausedAt,
        pausedUntil: pausedUntil ?? this.pausedUntil,
        canceledAt: canceledAt ?? this.canceledAt,
      );
}

/// R1. Live membership status (canonical).
MembershipStatus computeMembershipStatus(Membership m, Clock clock) {
  if (m.canceledAt != null) return MembershipStatus.canceled;
  final now = clock.now();
  if (m.pausedUntil != null && m.pausedUntil!.isAfter(now)) {
    return MembershipStatus.paused;
  }
  if (m.expiresAt != null) {
    if (m.expiresAt!.isBefore(now) || m.expiresAt == now) return MembershipStatus.expired;
    final inADay = now.add(const Duration(days: 1));
    if (!m.expiresAt!.isAfter(inADay)) return MembershipStatus.expiring;
  }
  return MembershipStatus.active;
}

/// Retention-relevant eligibility: paused members still count as present.
bool isActiveForRetention(Membership m, Clock clock) {
  final status = computeMembershipStatus(m, clock);
  return status == MembershipStatus.active ||
      status == MembershipStatus.paused ||
      status == MembershipStatus.frozen ||
      status == MembershipStatus.expiring;
}

/// R2. Check-in eligibility.
bool canCheckIn(Membership m, Clock clock) {
  if (computeMembershipStatus(m, clock) case MembershipStatus.canceled || MembershipStatus.expired) {
    return false;
  }
  return clock.now().isAtSameMomentAs(m.startedAt) ||
      clock.now().isAfter(m.startedAt);
}

/// AppRole mirrors the DB profiles.role check.
enum AppRole { owner, frontDesk, trainer, member }

bool isOwnerOrDesk(AppRole role) =>
    role == AppRole.owner || role == AppRole.frontDesk;
