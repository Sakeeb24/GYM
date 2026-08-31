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

  Future<void> signInWithUsername(String username, String password) =>
      repo.signInWithUsername(username, password);

  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String activationToken,
    required String username,
    required String password,
  }) =>
      repo.registerMember(
        fullName: fullName,
        phone: phone,
        activationToken: activationToken,
        username: username,
        password: password,
      );

  Future<void> signOut() => repo.signOut();

  Future<bool> isUsernameTaken(String username) => repo.isUsernameTaken(username);
}

final authActionsProvider = Provider((ref) => AuthActions(ref.watch(authRepositoryProvider)));
