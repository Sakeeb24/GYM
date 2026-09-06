// no_show.dart
import 'clock.dart';
import 'attendance.dart';
import 'membership_status.dart';

/// Input for the no-show scan rule (R4).
class NoShowInput {
  final String memberId;
  final String gymId;
  final Membership membership;
  final List<Attendance> recentCheckIns; // last attendance(s)
  final int inactivityThresholdDays;

  NoShowInput({
    required this.memberId,
    required this.gymId,
    required this.membership,
    required this.recentCheckIns,
    required this.inactivityThresholdDays,
  });
}

/// R4. Returns true if the member should open a no-show case.
bool shouldOpenNoShowCase(NoShowInput input, Clock clock) {
  // Exclude non-retention-eligible memberships (canceled/expired fully).
  if (!isActiveForRetention(input.membership, clock)) return false;

  DateTime? lastCheckIn;
  if (input.recentCheckIns.isNotEmpty) {
    lastCheckIn = input.recentCheckIns
        .map((a) => a.checkInAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  if (lastCheckIn == null) return true; // never checked in this period

  final threshold = Duration(days: input.inactivityThresholdDays);
  return clock.now().difference(lastCheckIn) >= threshold;
}
