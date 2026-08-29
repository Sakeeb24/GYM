// lib/features/auth/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/profile.dart';
import '../../core/services/supabase_client.dart';

/// Abstraction over auth + profile fetches. The UI depends on this interface
/// (testable; no Supabase in the widget layer).
abstract class AuthRepository {
  Stream<AuthState> authState();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInWithOtp(String email);
  Future<void> signOut();
  Future<Profile?> currentProfile();
  Stream<Profile?> watchProfile();
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient? _client;

  SupabaseAuthRepository([SupabaseClient? client]) : _client = client;

  SupabaseClient get client => _client ?? AppSupabase.client;

  @override
  Stream<AuthState> authState() {
    try {
      return client.auth.onAuthStateChange;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    final res = await client.auth.signInWithPassword(email: email, password: password);
    if (res.user == null) throw StateError('Sign in failed');
  }

  @override
  Future<void> signInWithOtp(String email) async {
    await client.auth.signInWithOtp(email: email);
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<Profile?> currentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final res = await client.from('profiles').select().eq('user_id', user.id).maybeSingle();
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
}
