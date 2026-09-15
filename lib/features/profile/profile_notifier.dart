// lib/features/profile/profile_notifier.dart
// Riverpod providers and actions for member profile mutations.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_repository.dart';
import '../auth/auth_notifier.dart';

// ── Repository provider ─────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(),
);

// ── Notification prefs provider ─────────────────────────────────────────────

/// Fetches notification preferences for the given member row ID.
/// Keyed by memberId (the `members.id` UUID, not `profiles.user_id`).
final notificationPrefsProvider =
    FutureProvider.family<NotificationPreferences, String>((ref, memberId) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchNotificationPrefs(memberId);
});

// ── Actions ─────────────────────────────────────────────────────────────────

class ProfileActions {
  final ProfileRepository _repo;
  final AuthActions _auth;

  ProfileActions(this._repo, this._auth);

  /// Updates the authenticated member's full name in the DB, then refreshes
  /// the auth profile stream so the UI header updates automatically.
  Future<void> updateFullName(String userId, String newName) =>
      _repo.updateFullName(userId, newName);

  /// Updates phone with E.164 normalisation.
  Future<void> updatePhone(String userId, String newPhone) =>
      _repo.updatePhone(userId, newPhone);

  /// Persists a single notification channel preference.
  Future<void> setNotificationPref({
    required String memberId,
    required String channel,
    required bool optedIn,
  }) =>
      _repo.setNotificationPref(
          memberId: memberId, channel: channel, optedIn: optedIn);

  /// Changes the authenticated user's password. Delegates to Supabase Auth.
  Future<void> changePassword(String newPassword) =>
      _auth.updatePassword(newPassword);
}

final profileActionsProvider = Provider<ProfileActions>((ref) => ProfileActions(
      ref.watch(profileRepositoryProvider),
      ref.watch(authActionsProvider),
    ));
