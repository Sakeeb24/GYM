// lib/features/auth/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/profile.dart';
import '../../core/services/supabase_client.dart';

/// Abstraction over auth + profile fetches. The UI depends on this interface
/// (testable; no Supabase in the widget layer).
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
    final res = await client.auth.signInWithPassword(
      email: _syntheticEmail(username.trim().toLowerCase()),
      password: password,
    );
    if (res.user == null) throw StateError('Sign in failed');
  }

  /// Predefined test phone numbers and OTPs for testing and verification
  static const Map<String, String> testPhoneOtps = {
    '+917019707247': '123456',
    '+919876543210': '123456',
    '+15555550100': '123456',
    '+919999999999': '123456',
    '+911234567890': '123456',
  };

  static bool isTestPhone(String phone) =>
      testPhoneOtps.containsKey(normalizePhone(phone));

  /// Normalizes phone number to E.164 format (+91 default for 10-digit numbers)
  static String normalizePhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!clean.startsWith('+')) {
      clean = clean.length == 10 ? '+91$clean' : '+$clean';
    }
    return clean;
  }

  @override
  Future<void> sendPhoneOtp(String phone) async {
    final clean = normalizePhone(phone);
    if (testPhoneOtps.containsKey(clean)) {
      try {
        await client.auth.signInWithOtp(phone: clean);
      } catch (_) {
        // Test numbers are verified directly via registerMember edge function
      }
      return;
    }
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
    // functions.invoke throws on network error; check for API-level errors.
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data.containsKey('error')) {
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
        .select()
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

