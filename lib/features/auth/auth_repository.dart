// lib/features/auth/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/profile.dart';
import '../../core/services/supabase_client.dart';

/// Abstraction over auth + profile fetches. The UI depends on this interface
/// (testable; no direct Supabase in the widget layer).
abstract class AuthRepository {
  Stream<AuthState> authState();

  /// Signs in using a username. Internally constructs the synthetic email
  /// ({username}@liftflow.internal) — users never see or type the email.
  Future<void> signInWithUsername(String username, String password);

  /// Sends a phone OTP for registration. Called before account creation.
  Future<void> sendPhoneOtp(String phone);

  /// Registers a new member via the server-side Edge Function.
  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String otpToken,
    required String username,
    required String password,
  });

  /// Password reset flow: Step 1 requests OTP for registered username.
  Future<String> requestPasswordReset(String username);

  /// Password reset flow: Step 2 verifies OTP and sets new password.
  Future<void> completePasswordReset({
    required String username,
    required String otpToken,
    required String newPassword,
  });

  Future<void> signOut();
  Future<Profile?> currentProfile();
  Stream<Profile?> watchProfile();

  /// Checks if a username is already taken. Returns true if taken.
  Future<bool> isUsernameTaken(String username);
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient? _client;

  SupabaseAuthRepository([SupabaseClient? client]) : _client = client;

  SupabaseClient get client => _client ?? AppSupabase.client;

  /// Synthetic email pattern: {username}@liftflow.internal
  static String _syntheticEmail(String username) => '$username@liftflow.internal';

  @override
  Stream<AuthState> authState() {
    try {
      return client.auth.onAuthStateChange;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<void> signInWithUsername(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    final res = await client.auth.signInWithPassword(
      email: _syntheticEmail(cleanUsername),
      password: password,
    );
    if (res.user == null) throw StateError('Sign in failed');
  }

  /// Normalizes phone number to E.164 format (+91 default for 10-digit Indian numbers)
  static String normalizePhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (clean.startsWith('00')) {
      clean = '+${clean.substring(2)}';
    } else if (clean.startsWith('0') && clean.length == 11) {
      clean = '+91${clean.substring(1)}';
    } else if (!clean.startsWith('+')) {
      clean = clean.length == 10 ? '+91$clean' : '+$clean';
    }
    return clean;
  }

  @override
  Future<void> sendPhoneOtp(String phone) async {
    final clean = normalizePhone(phone);
    await client.auth.signInWithOtp(phone: clean);
  }

  @override
  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String otpToken,
    required String username,
    required String password,
  }) async {
    final res = await client.functions.invoke(
      'registerMember',
      body: {
        'full_name': fullName.trim(),
        'phone': normalizePhone(phone),
        'otp_token': otpToken.trim(),
        'username': username.trim().toLowerCase(),
        'password': password,
      },
    );
    final data = res.data;
    if (data is Map && data.containsKey('error')) {
      throw StateError(data['error'] as String);
    }
  }

  @override
  Future<String> requestPasswordReset(String username) async {
    final cleanUser = username.trim().toLowerCase();
    try {
      final res = await client.functions.invoke(
        'recoverPassword',
        body: {
          'action': 'request_otp',
          'username': cleanUser,
        },
      );
      final data = res.data;
      if (data is Map) {
        if (data.containsKey('error')) {
          throw StateError(data['error'] as String);
        }
        return (data['masked_phone'] as String?) ?? 'your registered phone';
      }
      return 'your registered phone';
    } catch (_) {
      // Fallback: lookup profile phone directly if edge function is deploying
      final profile = await client
          .from('profiles')
          .select('phone')
          .eq('username', cleanUser)
          .maybeSingle();
      if (profile == null) throw StateError('No account found with this username');
      final phone = profile['phone'] as String?;
      if (phone == null || phone.isEmpty) {
        throw StateError('No phone number is registered for this account');
      }
      await client.auth.signInWithOtp(phone: phone);
      final masked = phone.length > 4 ? '${phone.substring(0, 3)} *** *** ${phone.substring(phone.length - 4)}' : '****';
      return masked;
    }
  }

  @override
  Future<void> completePasswordReset({
    required String username,
    required String otpToken,
    required String newPassword,
  }) async {
    final cleanUser = username.trim().toLowerCase();
    final res = await client.functions.invoke(
      'recoverPassword',
      body: {
        'action': 'reset_password',
        'username': cleanUser,
        'otp_token': otpToken.trim(),
        'new_password': newPassword,
      },
    );
    final data = res.data;
    if (data is Map && data.containsKey('error')) {
      throw StateError(data['error'] as String);
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<Profile?> currentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final res = await client
        .from('profiles')
        .select('user_id, gym_id, full_name, email, role, status, username, phone, phone_verified, is_profile_complete, created_at, updated_at')
        .eq('user_id', user.id)
        .maybeSingle();
    if (res == null) return null;
    return Profile.fromMap(Map<String, dynamic>.from(res as Map));
  }

  @override
  Stream<Profile?> watchProfile() {
    try {
      return client.auth.onAuthStateChange.asyncMap((_) => currentProfile());
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<bool> isUsernameTaken(String username) async {
    final res = await client
        .from('profiles')
        .select('user_id')
        .eq('username', username.trim().toLowerCase())
        .maybeSingle();
    return res != null;
  }
}
