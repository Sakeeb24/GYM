// renewal.dart
import 'clock.dart';
import 'membership_status.dart';

/// R6/R7. Input for renewal eligibility + reminder windowing.
class RenewalInput {
  final String memberId;
  final String gymId;
  final Membership membership;
  final bool commOptedIn;            // email/push opted in
  final List<int> reminderWindows;   // e.g. [14, 7, 3]
  final int postExpiryDays;          // e.g. 3

  RenewalInput({
    required this.memberId,
    required this.gymId,
    required this.membership,
    required this.commOptedIn,
    this.reminderWindows = const [14, 7, 3],
    this.postExpiryDays = 3,
  });

  RenewalInput copyWith({
    String? memberId,
    String? gymId,
    Membership? membership,
    bool? commOptedIn,
    List<int>? reminderWindows,
    int? postExpiryDays,
  }) =>
      RenewalInput(
        memberId: memberId ?? this.memberId,
        gymId: gymId ?? this.gymId,
        membership: membership ?? this.membership,
        commOptedIn: commOptedIn ?? this.commOptedIn,
        reminderWindows: reminderWindows ?? this.reminderWindows,
        postExpiryDays: postExpiryDays ?? this.postExpiryDays,
      );
}

/// R6. A membership is renewal-eligible when active/expiring/expired, not
/// canceled, and the member has not opted out of renewal comms.
bool renewalEligible(RenewalInput input, Clock clock) {
  final status = computeMembershipStatus(input.membership, clock);
  final eligibleStatus = switch (status) {
    MembershipStatus.active ||
    MembershipStatus.expiring ||
    MembershipStatus.expired => true,
    _ => false,
  };
  if (!eligibleStatus) return false;
  if (!input.commOptedIn) return false; // comm opt-out stop condition
  return true;
}

bool commOptedOut(RenewalInput input) => !input.commOptedIn;

/// R7. Given days until expiry, returns the reminder stage label that is due now
/// (the largest window <= daysUntilExpiry), or null if no window due.
/// Returns 'post_expiry' when expired but within postExpiryDays.
String? dueReminderStage(RenewalInput input, Clock clock) {
  if (!renewalEligible(input, clock)) return null;
  final expiry = input.membership.expiresAt;
  if (expiry == null) return null;
  final now = clock.now();
  final daysUntil = expiry.difference(now).inDays;

  if (daysUntil < 0) {
    // expired; post-expiry window
    if (-daysUntil <= input.postExpiryDays) return 'post_expiry';
    return null; // past post-expiry grace
  }

  String? stage;
  for (final w in input.reminderWindows) {
    if (daysUntil <= w) stage = 'd_$w';
  }
  return stage;
}
