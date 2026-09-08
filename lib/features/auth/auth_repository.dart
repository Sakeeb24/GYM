import 'package:flutter/foundation.dart';
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

  /// Password reset flow: Sends a password recovery link to the user's registered email address.
  Future<void> sendPasswordResetEmail(String email);

  /// Password reset flow: Updates the authenticated recovery user's password.
  Future<void> updatePassword(String newPassword);

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

    // 3. Username with synthetic email ({username}@liftflow.internal or {username}@liftflow.app)
    final cleanUsername = clean.toLowerCase();
    try {
      final res = await client.auth.signInWithPassword(
        email: '$cleanUsername@liftflow.internal',
        password: password,
      );
      if (res.user != null) return;
    } catch (_) {
      final res = await client.auth.signInWithPassword(
        email: '$cleanUsername@liftflow.app',
        password: password,
      );
      if (res.user != null) return;
      rethrow;
    }
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
    final cleanName = fullName.trim();
    final cleanPhone = normalizePhone(phone);
    final cleanToken = activationToken.trim();
    final cleanUser = username.trim().toLowerCase();

    if (cleanName.length < 2) {
      throw StateError('Full name must be at least 2 characters.');
    }
    if (cleanPhone.isEmpty || cleanPhone.length < 8) {
      throw StateError('Please enter a valid phone number.');
    }
    if (cleanToken.isEmpty) {
      throw StateError('Gym activation verification is required. Please scan or enter your gym QR code in Step 2.');
    }
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(cleanUser)) {
      throw StateError('Username must be 3-30 lowercase alphanumeric characters or underscores.');
    }
    if (password.length < 8) {
      throw StateError('Password must be at least 8 characters.');
    }

    // Pre-flight uniqueness checks against database
    final existingUser = await isUsernameTaken(cleanUser);
    if (existingUser) {
      throw const FunctionException(
        status: 409,
        details: 'Username is already taken. Please choose another username.',
      );
    }

    final existingPhone = await client
        .from('profiles')
        .select('user_id')
        .eq('phone', cleanPhone)
        .maybeSingle();
    if (existingPhone != null) {
      throw const FunctionException(
        status: 409,
        details: 'This phone number is already registered. Please log in with your username and password.',
      );
    }

    try {
      await EdgeFunctionClient.post(
        'registerMember',
        body: {
          'full_name': cleanName,
          'phone': cleanPhone,
          'activation_token': cleanToken,
          'username': cleanUser,
          'password': password,
        },
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();

      if (errStr.contains('already registered') || errStr.contains('already exists') || errStr.contains('duplicate')) {
        throw const FunctionException(
          status: 409,
          details: 'This phone number is already registered. Please log in with your username and password.',
        );
      }
      if (errStr.contains('username') && (errStr.contains('taken') || errStr.contains('already'))) {
        throw const FunctionException(
          status: 409,
          details: 'Username is already taken. Please choose another username.',
        );
      }
      if (errStr.contains('expired') || errStr.contains('revoked') || errStr.contains('consumed') || errStr.contains('qr code') || errStr.contains('activation')) {
        if (e is FunctionException) rethrow;
        throw const FunctionException(
          status: 410,
          details: 'This activation QR has expired or is invalid. Please ask your gym owner for a new QR code.',
        );
      }

      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty || !clean.contains('@')) {
      throw StateError('Please enter a valid email address.');
    }

    String? redirectUrl;
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        redirectUrl = origin.contains('github.io') ? '$origin/GYM/' : '$origin/';
      } catch (_) {
        redirectUrl = 'https://sakeeb24.github.io/GYM/';
      }
    }

    await client.auth.resetPasswordForEmail(
      clean,
      redirectTo: redirectUrl,
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (newPassword.length < 8) {
      throw StateError('Password must be at least 8 characters.');
    }
    await client.auth.updateUser(
      UserAttributes(password: newPassword),
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
