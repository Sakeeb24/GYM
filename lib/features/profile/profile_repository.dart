// lib/features/profile/profile_repository.dart
// Profile mutations: name, phone, and notification preference persistence.
import '../../core/services/supabase_client.dart';
import '../auth/auth_repository.dart';

// ── Notification preference model ──────────────────────────────────────────

class NotificationPreferences {
  final bool pushEnabled;
  final bool emailEnabled;

  const NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
  });

  NotificationPreferences copyWith({bool? pushEnabled, bool? emailEnabled}) =>
      NotificationPreferences(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
      );
}

// ── Repository interface ────────────────────────────────────────────────────

abstract class ProfileRepository {
  /// Updates the full_name field on the profiles table.
  Future<void> updateFullName(String userId, String newName);

  /// Updates the phone field on the profiles table (E.164 normalised).
  Future<void> updatePhone(String userId, String newPhone);

  /// Fetches all notification channel preferences for a member.
  /// Returns defaults (all opted-in) if no rows exist yet.
  Future<NotificationPreferences> fetchNotificationPrefs(String memberId);

  /// Upserts a single channel preference for a member.
  Future<void> setNotificationPref({
    required String memberId,
    required String channel, // 'push' | 'email'
    required bool optedIn,
  });
}

// ── Supabase implementation ─────────────────────────────────────────────────

class SupabaseProfileRepository implements ProfileRepository {
  @override
  Future<void> updateFullName(String userId, String newName) async {
    final clean = newName.trim();
    if (clean.length < 2) {
      throw StateError('Full name must be at least 2 characters.');
    }
    await AppSupabase.client
        .from('profiles')
        .update({'full_name': clean})
        .eq('user_id', userId);
  }

  @override
  Future<void> updatePhone(String userId, String newPhone) async {
    final e164 = SupabaseAuthRepository.normalizePhone(newPhone);
    if (e164.length < 8) {
      throw StateError('Please enter a valid phone number.');
    }
    await AppSupabase.client
        .from('profiles')
        .update({'phone': e164})
        .eq('user_id', userId);
  }

  @override
  Future<NotificationPreferences> fetchNotificationPrefs(
      String memberId) async {
    final rows = await AppSupabase.client
        .from('communication_preferences')
        .select('channel, opted_in')
        .eq('member_id', memberId);

    bool push = true;
    bool email = true;

    for (final row in (rows as List)) {
      final channel = row['channel'] as String;
      final optedIn = (row['opted_in'] as bool?) ?? true;
      if (channel == 'push') push = optedIn;
      if (channel == 'email') email = optedIn;
    }

    return NotificationPreferences(pushEnabled: push, emailEnabled: email);
  }

  @override
  Future<void> setNotificationPref({
    required String memberId,
    required String channel,
    required bool optedIn,
  }) async {
    await AppSupabase.client.from('communication_preferences').upsert(
      {
        'member_id': memberId,
        'channel': channel,
        'opted_in': optedIn,
      },
      onConflict: 'member_id,channel',
    );
  }
}
