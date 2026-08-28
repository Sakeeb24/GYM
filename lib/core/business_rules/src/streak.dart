import 'package:flutter/foundation.dart';
import 'attendance.dart';

/// R3. Streak result.
@immutable
class StreakResult {
  final int current;
  final int longest;

  const StreakResult({required this.current, required this.longest});
}

/// R3. Recompute a member's streak from their sorted check-ins.
///
/// A streak is the longest run of *consecutive calendar days* that each have
/// at least one check-in. `current` is the length of the trailing run ending at
/// the most recent check-in; `longest` is the maximum run ever. A gap of >= 1
/// calendar day breaks a run (resetting `current`).
///
/// `minConsecutive` is the minimum run length to be considered a valid streak
/// (gym_setting `streak_required_consecutive`, default 1).
StreakResult computeStreak(
  List<Attendance> checkIns, {
  int minConsecutive = 1,
  int initialLongest = 0,
}) {
  if (checkIns.isEmpty) {
    return StreakResult(current: 0, longest: initialLongest);
  }

  // Distinct calendar days with a check-in, ascending.
  final days = <DateTime>{};
  for (final a in checkIns) {
    days.add(DateTime(a.checkInAt.year, a.checkInAt.month, a.checkInAt.day));
  }
  final sorted = days.toList()..sort((a, b) => a.compareTo(b));

  int run = 1;
  int longest = initialLongest;
  DateTime prev = sorted.first;
  if (run > longest) longest = run;

  for (var i = 1; i < sorted.length; i++) {
    final d = sorted[i];
    if (d == prev.add(const Duration(days: 1))) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
    prev = d;
  }

  final current = run >= minConsecutive ? run : 0;
  final effectiveLongest = longest >= minConsecutive ? longest : initialLongest;
  return StreakResult(current: current, longest: effectiveLongest);
}
