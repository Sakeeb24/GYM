// lib/features/auth/auth_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/core/models/profile.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => SupabaseAuthRepository());

final authStateProvider = StreamProvider<Profile?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchProfile();
});

class AuthActions {
  final AuthRepository repo;
  AuthActions(this.repo);

  Future<void> signInWithEmail(String email, String password) => repo.signInWithEmail(email, password);
  Future<void> signInWithOtp(String email) => repo.signInWithOtp(email);
  Future<void> signOut() => repo.signOut();
}

final authActionsProvider = Provider((ref) => AuthActions(ref.watch(authRepositoryProvider)));
