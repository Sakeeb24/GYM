// test/features/red_list/red_list_severity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';

void main() {
  group('Red List Inactivity & Severity Invariant Tests', () {
    final t0 = DateTime(2026, 9, 1, 12, 0, 0);
    final clock = FixedClock(t0);

    final activeMembership = Membership(
      id: 'mem_1',
      memberId: 'usr_1',
      gymId: 'gym_1',
      startedAt: t0.subtract(const Duration(days: 90)),
      expiresAt: t0.add(const Duration(days: 30)),
    );

    test('3-5 days inactive is below default 7-day no-show trigger', () {
      final input = NoShowInput(
        memberId: 'usr_1',
        gymId: 'gym_1',
        membership: activeMembership,
        recentCheckIns: [
          Attendance(
            memberId: 'usr_1',
            gymId: 'gym_1',
            checkInAt: t0.subtract(const Duration(days: 4)),
          ),
        ],
        inactivityThresholdDays: 7,
      );

      expect(shouldOpenNoShowCase(input, clock), isFalse);
    });

    test('8 days inactive triggers no-show case opening (Orange risk tier)', () {
      final input = NoShowInput(
        memberId: 'usr_1',
        gymId: 'gym_1',
        membership: activeMembership,
        recentCheckIns: [
          Attendance(
            memberId: 'usr_1',
            gymId: 'gym_1',
            checkInAt: t0.subtract(const Duration(days: 8)),
          ),
        ],
        inactivityThresholdDays: 7,
      );

      expect(shouldOpenNoShowCase(input, clock), isTrue);
    });

    test('15 days inactive triggers no-show case opening (Red / Critical risk tier)', () {
      final input = NoShowInput(
        memberId: 'usr_1',
        gymId: 'gym_1',
        membership: activeMembership,
        recentCheckIns: [
          Attendance(
            memberId: 'usr_1',
            gymId: 'gym_1',
            checkInAt: t0.subtract(const Duration(days: 15)),
          ),
        ],
        inactivityThresholdDays: 7,
      );

      expect(shouldOpenNoShowCase(input, clock), isTrue);
    });

    test('Expired membership is excluded from no-show scan', () {
      final expiredMembership = activeMembership.copyWith(
        expiresAt: t0.subtract(const Duration(days: 10)),
      );

      final input = NoShowInput(
        memberId: 'usr_1',
        gymId: 'gym_1',
        membership: expiredMembership,
        recentCheckIns: [],
        inactivityThresholdDays: 7,
      );

      expect(shouldOpenNoShowCase(input, clock), isFalse);
    });

    test('Canceled membership is excluded from no-show scan', () {
      final canceledMembership = activeMembership.copyWith(
        canceledAt: t0.subtract(const Duration(days: 2)),
      );

      final input = NoShowInput(
        memberId: 'usr_1',
        gymId: 'gym_1',
        membership: canceledMembership,
        recentCheckIns: [],
        inactivityThresholdDays: 7,
      );

      expect(shouldOpenNoShowCase(input, clock), isFalse);
    });
  });
}
