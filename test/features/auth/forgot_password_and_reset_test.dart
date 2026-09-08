// test/features/auth/forgot_password_and_reset_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/auth/auth_repository.dart';
import 'package:liftflow/features/auth/presentation/forgot_password_screen.dart';
import 'package:liftflow/features/auth/presentation/reset_password_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestAuthRepository implements AuthRepository {
  String? lastResetEmail;
  String? lastUpdatedPassword;
  bool shouldFailReset = false;
  bool shouldFailUpdate = false;
  bool signedOut = false;

  @override
  Stream<AuthState> authState() => const Stream.empty();

  @override
  Future<void> signInWithUsername(String username, String password) async {}

  @override
  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String activationToken,
    required String username,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (shouldFailReset) {
      throw const AuthException('Rate limit exceeded');
    }
    lastResetEmail = email;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (shouldFailUpdate) {
      throw const AuthException('Recovery token expired');
    }
    lastUpdatedPassword = newPassword;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Future<Profile?> currentProfile() async => null;

  @override
  Stream<Profile?> watchProfile() => const Stream.empty();

  @override
  Future<bool> isUsernameTaken(String username) async => false;
}

void main() {
  group('Forgot Password & Reset Password Flow Tests', () {
    testWidgets('ForgotPasswordScreen validates email input and sends reset link', (tester) async {
      final fakeAuth = TestAuthRepository();
      final router = GoRouter(
        initialLocation: '/forgot-password',
        routes: [
          GoRoute(path: '/forgot-password', builder: (ctx, st) => const ForgotPasswordScreen()),
          GoRoute(path: '/login', builder: (ctx, st) => const Scaffold(body: Text('Login Screen'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RESET PASSWORD'), findsOneWidget);
      expect(find.text('Forgot Your Password?'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);

      // Empty submission
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);

      // Invalid format
      await tester.enterText(find.byType(TextField).first, 'invalid-email');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);

      // Valid email -> dispatches reset link and shows confirmation
      await tester.enterText(find.byType(TextField).first, 'member@testgym.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(fakeAuth.lastResetEmail, 'member@testgym.com');
      expect(find.text('Check your email'), findsOneWidget);
      expect(
        find.textContaining('If an account exists for this email, we sent a password reset link.'),
        findsOneWidget,
      );
      expect(find.text('Return to Login'), findsOneWidget);

      // Tap Return to Login
      await tester.tap(find.text('Return to Login'));
      await tester.pumpAndSettle();
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('ResetPasswordScreen validates password inputs and updates password', (tester) async {
      final fakeAuth = TestAuthRepository();
      final router = GoRouter(
        initialLocation: '/reset-password',
        routes: [
          GoRoute(path: '/reset-password', builder: (ctx, st) => const ResetPasswordScreen()),
          GoRoute(path: '/login', builder: (ctx, st) => const Scaffold(body: Text('Login Screen'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RESET YOUR PASSWORD'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Empty submit
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.text('Please enter your new password.'), findsOneWidget);

      // Short password (< 8 chars)
      await tester.enterText(find.byType(TextField).at(0), 'short');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.text('Password must be at least 8 characters.'), findsOneWidget);

      // Mismatch
      await tester.enterText(find.byType(TextField).at(0), 'NewSecurePass@2026');
      await tester.enterText(find.byType(TextField).at(1), 'MismatchPass@2026');
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.text('Passwords do not match. Please re-enter.'), findsOneWidget);

      // Valid matching update
      await tester.enterText(find.byType(TextField).at(1), 'NewSecurePass@2026');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(fakeAuth.lastUpdatedPassword, 'NewSecurePass@2026');
      expect(fakeAuth.signedOut, isTrue);
      expect(find.text('Password Updated Successfully'), findsOneWidget);
      expect(find.text('Go to Login'), findsOneWidget);

      // Tap Go to Login
      await tester.tap(find.text('Go to Login'));
      await tester.pumpAndSettle();
      expect(find.text('Login Screen'), findsOneWidget);
    });
  });
}
