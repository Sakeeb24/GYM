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

      // Verify UI elements
      expect(find.text('Personal Details'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Tap continue with empty inputs
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter your full name.'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextField).at(0), 'John Doe');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter a valid phone number (e.g. +91 98765 43210).'), findsOneWidget);

      // Enter valid phone
      await tester.enterText(find.byType(TextField).at(1), '+1 555 123 4567');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(fakeRepo.sentPhone, '+1 555 123 4567');
      expect(find.text('OTP Page'), findsOneWidget);
    });

    testWidgets('OtpScreen validates 6-digit code and proceeds to account setup', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final router = GoRouter(
        initialLocation: '/otp',
        routes: [
          GoRoute(
            path: '/otp',
            builder: (ctx, st) => const OtpScreen(fullName: 'John Doe', phone: '+1 555 123 4567'),
          ),
          GoRoute(path: '/account-setup', builder: (ctx, st) => const Scaffold(body: Text('Setup Page'))),
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

      expect(find.text('Enter Verification Code'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);

      // Try with invalid OTP
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
              phone: '+1 555 123 4567',
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

      expect(find.text('Create Login'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Try empty submission
      await tester.tap(find.text('Create Account'));
      await tester.pump();
      expect(find.text('Please choose a username.'), findsOneWidget);

      // Fill valid credentials
      await tester.enterText(find.byType(TextField).at(0), 'johndoe');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.enterText(find.byType(TextField).at(2), 'mismatchpass');
      await tester.tap(find.text('Create Account'));
      await tester.pump();
      expect(find.text('Passwords do not match. Please re-enter.'), findsOneWidget);

      // Match passwords
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(fakeRepo.registered, isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(find.text('Login Screen'), findsOneWidget);
    });
  });
}
