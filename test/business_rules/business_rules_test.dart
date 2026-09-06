import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';

void main() {
  group('R1 computeMembershipStatus', () {
    final t0 = DateTime(2026, 8, 28, 12, 0, 0);
    final clock = FixedClock(t0);

    Membership mem({DateTime? expires, DateTime? pausedUntil, DateTime? canceled}) => Membership(
          id: 'm1', memberId: 'u1', gymId: 'g1',
          startedAt: t0.subtract(const Duration(days: 60)),
          expiresAt: expires,
          pausedUntil: pausedUntil,
          canceledAt: canceled,
        );

    test('active when future expiry, not paused, not canceled', () {
      expect(computeMembershipStatus(mem(expires: t0.add(const Duration(days: 10))), clock), MembershipStatus.active);
    });
    test('canceled takes precedence', () {
      expect(computeMembershipStatus(mem(expires: t0.add(const Duration(days: 10)), canceled: t0), clock), MembershipStatus.canceled);
    });
    test('paused when pausedUntil in future', () {
      expect(computeMembershipStatus(mem(expires: t0.add(const Duration(days: 10)), pausedUntil: t0.add(const Duration(days: 3))), clock), MembershipStatus.paused);
    });
    test('expired when expiresAt in past', () {
      expect(computeMembershipStatus(mem(expires: t0.subtract(const Duration(days: 1))), clock), MembershipStatus.expired);
    });
    test('expiring within 24h of expiry', () {
      expect(computeMembershipStatus(mem(expires: t0.add(const Duration(hours: 20))), clock), MembershipStatus.expiring);
    });
    test('null expiry -> active', () {
      expect(computeMembershipStatus(mem(expires: null), clock), MembershipStatus.active);
    });
  });

  group('R2 canCheckIn', () {
    final t0 = DateTime(2026, 8, 28, 12);
    final clock = FixedClock(t0);
    Membership activeMem = Membership(id: 'm', memberId: 'u', gymId: 'g', startedAt: t0.subtract(const Duration(days: 1)));
    Membership canceledMem = activeMem.copyWith(canceledAt: t0);
    Membership expiredMem = activeMem.copyWith(expiresAt: t0.subtract(const Duration(days: 1)));

    test('active membership can check in', () { expect(canCheckIn(activeMem, clock), isTrue); });
    test('canceled membership denied', () { expect(canCheckIn(canceledMem, clock), isFalse); });
    test('expired membership denied', () { expect(canCheckIn(expiredMem, clock), isFalse); });
    test('paused membership allowed', () { expect(canCheckIn(activeMem.copyWith(pausedUntil: t0.add(const Duration(days: 2))), clock), isTrue); });
  });

  group('R3 streak', () {
    final t0 = DateTime(2026, 8, 28, 12);
    Attendance a(int dayOffset) => Attendance(memberId: 'u', gymId: 'g', checkInAt: t0.subtract(Duration(days: 3 - dayOffset)));

    test('3 consecutive days -> current 3, longest 3', () {
      final s = computeStreak([a(0), a(1), a(2)]); // days 3,2,1 before today
      expect(s.current, 3); expect(s.longest, 3);
    });
    test('gap breaks streak', () {
      final s = computeStreak([a(0), a(1)]); // only 2 consecutive
      expect(s.current, 2); expect(s.longest, 2);
    });
    test('empty -> zeros', () {
      final s = computeStreak([]);
      expect(s.current, 0); expect(s.longest, 0);
    });
    test('duplicate same-day does not extend', () {
      final s = computeStreak([a(0), a(0), a(1)]);
      expect(s.current, 2); expect(s.longest, 2);
    });
  });

  group('R4 no-show', () {
    final t0 = DateTime(2026, 8, 28, 12);
    final clock = FixedClock(t0);
    final active = Membership(id: 'm', memberId: 'u', gymId: 'g', startedAt: t0.subtract(const Duration(days: 60)), expiresAt: t0.add(const Duration(days: 10)));

    test('8 days inactive >= 7d threshold -> true', () {
      final input = NoShowInput(memberId: 'u', gymId: 'g', membership: active,
        recentCheckIns: [Attendance(memberId: 'u', gymId: 'g', checkInAt: t0.subtract(const Duration(days: 8)))],
        inactivityThresholdDays: 7);
      expect(shouldOpenNoShowCase(input, clock), isTrue);
    });
    test('3 days inactive < 7d threshold -> false', () {
      final input = NoShowInput(memberId: 'u', gymId: 'g', membership: active,
        recentCheckIns: [Attendance(memberId: 'u', gymId: 'g', checkInAt: t0.subtract(const Duration(days: 3)))],
        inactivityThresholdDays: 7);
      expect(shouldOpenNoShowCase(input, clock), isFalse);
    });
    test('never checked in -> true', () {
      final input = NoShowInput(memberId: 'u', gymId: 'g', membership: active, recentCheckIns: [], inactivityThresholdDays: 7);
      expect(shouldOpenNoShowCase(input, clock), isTrue);
    });
    test('canceled membership excluded', () {
      final input = NoShowInput(memberId: 'u', gymId: 'g', membership: active.copyWith(canceledAt: t0),
        recentCheckIns: [], inactivityThresholdDays: 7);
      expect(shouldOpenNoShowCase(input, clock), isFalse);
    });
    test('expired membership excluded', () {
      final input = NoShowInput(memberId: 'u', gymId: 'g',
        membership: active.copyWith(expiresAt: t0.subtract(const Duration(days: 10))),
        recentCheckIns: [], inactivityThresholdDays: 7);
      expect(shouldOpenNoShowCase(input, clock), isFalse);
    });
  });

  group('R6/R7 renewal', () {
    final t0 = DateTime(2026, 8, 28, 12);
    final clock = FixedClock(t0);
    final eligible = RenewalInput(memberId: 'u', gymId: 'g',
      membership: Membership(id: 'm', memberId: 'u', gymId: 'g', startedAt: t0.subtract(const Duration(days: 30)), expiresAt: t0.add(const Duration(days: 12))),
      commOptedIn: true, reminderWindows: [14, 7, 3], postExpiryDays: 3);

    test('active + subscribed -> eligible', () { expect(renewalEligible(eligible, clock), isTrue); });
    test('opted out -> not eligible', () { expect(renewalEligible(eligible.copyWith(commOptedIn: false), clock), isFalse); });
    test('cancelled -> not eligible', () { expect(renewalEligible(eligible.copyWith(membership: eligible.membership.copyWith(canceledAt: t0)), clock), isFalse); });

    test('12 days until expiry -> d_14 window not due (12 < 14? yes), stage d_7', () {
      // expires in 12 days; windows [14,7,3]; largest w with days<=w is 14 (12<=14) -> d_14
      expect(dueReminderStage(eligible, clock), 'd_14');
    });
    test('7 days until expiry -> d_7', () {
      final e7 = eligible.copyWith(membership: eligible.membership.copyWith(expiresAt: t0.add(const Duration(days: 7))));
      expect(dueReminderStage(e7, clock), 'd_7');
    });
    test('2 days until expiry -> d_3', () {
      final e2 = eligible.copyWith(membership: eligible.membership.copyWith(expiresAt: t0.add(const Duration(days: 2))));
      expect(dueReminderStage(e2, clock), 'd_3');
    });
    test('expired within post-expiry -> post_expiry', () {
      final exp = eligible.copyWith(membership: eligible.membership.copyWith(expiresAt: t0.subtract(const Duration(days: 2))));
      expect(dueReminderStage(exp, clock), 'post_expiry');
    });
    test('expired beyond post-expiry -> null', () {
      final exp = eligible.copyWith(membership: eligible.membership.copyWith(expiresAt: t0.subtract(const Duration(days: 10))));
      expect(dueReminderStage(exp, clock), isNull);
    });
  });

  group('R8 payment', () {
    test('created -> pending valid', () {
      expect(isValidPaymentTransition(PaymentStatus.created, PaymentStatus.pending), isTrue);
    });
    test('pending -> succeeded valid', () {
      expect(isValidPaymentTransition(PaymentStatus.pending, PaymentStatus.succeeded), isTrue);
    });
    test('active terminal rejected', () {
      expect(isValidPaymentTransition(PaymentStatus.succeeded, PaymentStatus.failed), isFalse);
    });
    test('duplicate succeeded webhook -> null (idempotent)', () {
      final cur = Payment(id: 'p', providerReference: 'ch_1', idempotencyKey: 'k', amountCents: 1500, currency: 'USD', status: PaymentStatus.succeeded, createdAt: DateTime.now());
      expect(applyPaymentEvent(cur, 'ch_1', PaymentStatus.succeeded), isNull);
    });
    test('pending -> succeeded applies', () {
      final cur = Payment(id: 'p', providerReference: 'ch_2', idempotencyKey: 'k', amountCents: 1500, currency: 'USD', status: PaymentStatus.pending, createdAt: DateTime.now());
      final next = applyPaymentEvent(cur, 'ch_2', PaymentStatus.succeeded);
      expect(next?.status, PaymentStatus.succeeded);
    });
    test('invalid transition rejected', () {
      final cur = Payment(id: 'p', providerReference: 'ch_3', idempotencyKey: 'k', amountCents: 1500, currency: 'USD', status: PaymentStatus.failed, createdAt: DateTime.now());
      expect(applyPaymentEvent(cur, 'ch_3', PaymentStatus.succeeded), isNull);
    });
  });

  group('R10 authz', () {
    test('member can self check in', () { expect(roleCan(AppRole.member, Capability.selfCheckIn), isTrue); });
    test('member cannot manage staff', () { expect(roleCan(AppRole.member, Capability.manageStaff), isFalse); });
    test('front desk can manage red list', () { expect(roleCan(AppRole.frontDesk, Capability.manageRedList), isTrue); });
    test('front desk cannot manage plans', () { expect(roleCan(AppRole.frontDesk, Capability.managePlans), isFalse); });
    test('owner can do everything', () {
      for (final c in Capability.values) {
        expect(roleCan(AppRole.owner, c), isTrue, reason: 'owner $c');
      }
    });
    test('trainer cannot self-upgrade to owner', () {
      expect(roleCan(AppRole.trainer, Capability.manageSettings), isFalse);
    });
  });
}
