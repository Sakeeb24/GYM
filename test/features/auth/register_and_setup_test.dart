// test/features/auth/register_and_setup_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/auth/auth_repository.dart';
import 'package:liftflow/features/auth/presentation/register_screen.dart';
import 'package:liftflow/features/auth/presentation/otp_screen.dart';
import 'package:liftflow/features/auth/presentation/account_setup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRepository implements AuthRepository {
  String? sentPhone;
  bool registered = false;

  @override
  Stream<AuthState> authState() => const Stream.empty();

  @override
  Future<void> signInWithUsername(String username, String password) async {}

  @override
  Future<void> sendPhoneOtp(String phone) async {
    sentPhone = phone;
  }

  @override
  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String otpToken,
    required String username,
    required String password,
  }) async {
    registered = true;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<Profile?> currentProfile() async => null;

  @override
  Stream<Profile?> watchProfile() => const Stream.empty();

  @override
  Future<bool> isUsernameTaken(String username) async => false;

  @override
  Future<String> requestPasswordReset(String username) async => '+91******7247';

  @override
  Future<void> completePasswordReset({
    required String username,
    required String otpToken,
    required String newPassword,
  }) async {}
}

void main() {
  group('Registration Flow Screens & Buttons', () {
    testWidgets('RegisterScreen validates inputs and triggers OTP send', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final router = GoRouter(
        initialLocation: '/register',
        routes: [
          GoRoute(path: '/register', builder: (ctx, st) => const RegisterScreen()),
          GoRoute(path: '/otp', builder: (ctx, st) => const Scaffold(body: Text('OTP Page'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);

      // Try empty submission
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter your full name.'), findsOneWidget);

      // Enter name only
      await tester.enterText(find.byType(TextField).at(0), 'John Doe');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter a valid phone number (e.g. +91 98765 43210).'), findsOneWidget);

      // Enter valid phone
      await tester.enterText(find.byType(TextField).at(1), '7019707247');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(fakeRepo.sentPhone, '7019707247');
      expect(find.text('OTP Page'), findsOneWidget);
    });

    testWidgets('OtpScreen validates 6-digit code and resend timer button', (tester) async {
      final router = GoRouter(
        initialLocation: '/otp',
        routes: [
          GoRoute(
            path: '/otp',
            builder: (ctx, st) => const OtpScreen(
              fullName: 'John Doe',
              phone: '+91 7019707247',
            ),
          ),
          GoRoute(path: '/account-setup', builder: (ctx, st) => const Scaffold(body: Text('Setup Page'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VERIFY PHONE'), findsOneWidget);
      expect(find.textContaining('7019707247'), findsOneWidget);

      // Try invalid code
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pump();
      expect(find.text('Please enter the complete 6-digit verification code.'), findsOneWidget);

      // Enter 6 digits
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Setup Page'), findsOneWidget);
    });

    testWidgets('AccountSetupScreen validates passwords and registers member', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final router = GoRouter(
        initialLocation: '/setup',
        routes: [
          GoRoute(
            path: '/setup',
            builder: (ctx, st) => const AccountSetupScreen(
              fullName: 'John Doe',
              phone: '+91 7019707247',
              otpToken: '123456',
            ),
          ),
          GoRoute(path: '/login', builder: (ctx, st) => const Scaffold(body: Text('Login Screen'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Login'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Try empty submission
      await tester.tap(find.text('Complete Registration'));
      await tester.pump();
      expect(find.text('Please choose a username.'), findsOneWidget);

      // Fill valid credentials with mismatch
      await tester.enterText(find.byType(TextField).at(0), 'johndoe');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.enterText(find.byType(TextField).at(2), 'mismatchpass');
      await tester.tap(find.text('Complete Registration'));
      await tester.pump();
      expect(find.text('Passwords do not match. Please re-enter.'), findsOneWidget);

      // Match passwords
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Complete Registration'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(fakeRepo.registered, true);
    });
  });
}
