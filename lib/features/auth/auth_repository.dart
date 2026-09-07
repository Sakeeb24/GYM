import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/profile.dart';
import '../../core/services/edge_function_client.dart';
import '../../core/services/supabase_client.dart';

/// Abstraction over auth + profile fetches. The UI depends on this interface
/// (testable; no direct Supabase in the widget layer).
abstract class AuthRepository {
  Stream<AuthState> authState();

  /// Signs in using a username. Internally constructs the synthetic email
  /// ({username}@liftflow.internal) — users never see or type the email.
  Future<void> signInWithUsername(String username, String password);

  /// Registers a new member via the server-side Edge Function using a verified owner QR activation token.
  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String activationToken,
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
  Future<void> signInWithUsername(String identifier, String password) async {
    final clean = identifier.trim();
    if (clean.isEmpty) throw StateError('Identifier cannot be empty');

    // 1. Direct email sign in
    if (clean.contains('@')) {
      final res = await client.auth.signInWithPassword(
        email: clean.toLowerCase(),
        password: password,
      );
      if (res.user == null) throw StateError('Sign in failed');
      return;
    }

    // 2. Phone number identifier resolution
    final isPhoneLike = RegExp(r'^(\+?[0-9\s\-()]{8,15})$').hasMatch(clean);
    if (isPhoneLike) {
      final normalized = normalizePhone(clean);
      try {
        final profile = await client
            .from('profiles')
            .select('username')
            .eq('phone', normalized)
            .maybeSingle();
        if (profile != null && profile['username'] != null) {
          final u = (profile['username'] as String).toLowerCase();
          final res = await client.auth.signInWithPassword(
            email: _syntheticEmail(u),
            password: password,
          );
          if (res.user != null) return;
        }
      } catch (_) {
        // Fall back to direct username check
      }
    }

    // 3. Username with synthetic email ({username}@liftflow.internal)
    final cleanUsername = clean.toLowerCase();
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
  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String activationToken,
    required String username,
    required String password,
  }) async {
    await EdgeFunctionClient.post(
      'registerMember',
      body: {
        'full_name': fullName.trim(),
        'phone': normalizePhone(phone),
        'activation_token': activationToken.trim(),
        'username': username.trim().toLowerCase(),
        'password': password,
      },
    );
  }

  @override
  Future<String> requestPasswordReset(String username) async {
    final cleanUser = username.trim().toLowerCase();
    try {
      final data = await EdgeFunctionClient.post(
        'recoverPassword',
        body: {
          'action': 'request_otp',
          'username': cleanUser,
        },
      );
      return (data['masked_phone'] as String?) ?? 'your registered phone';
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
    await EdgeFunctionClient.post(
      'recoverPassword',
      body: {
        'action': 'reset_password',
        'username': cleanUser,
        'otp_token': otpToken.trim(),
        'new_password': newPassword,
      },
    );
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<Profile?> currentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final res = await client
        .from('profiles')
        .select('user_id, gym_id, full_name, email, role, status, username, phone, phone_verified, created_at, updated_at')
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
