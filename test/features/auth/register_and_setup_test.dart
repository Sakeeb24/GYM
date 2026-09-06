// test/features/auth/register_and_setup_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/auth/auth_repository.dart';
import 'package:liftflow/features/auth/member_activation_repository.dart';
import 'package:liftflow/features/auth/presentation/register_screen.dart';
import 'package:liftflow/features/auth/presentation/verify_gym_screen.dart';
import 'package:liftflow/features/auth/presentation/account_setup_screen.dart';
import 'package:liftflow/features/auth/presentation/owner_activation_qr_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRepository implements AuthRepository {
  bool registered = false;
  String? registeredToken;
  String? registeredUsername;

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
  }) async {
    registered = true;
    registeredToken = activationToken;
    registeredUsername = username;
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

class FakeMemberActivationRepository implements MemberActivationRepository {
  bool shouldFail = false;
  String? errorMessage;
  int tokenCounter = 1;

  @override
  Future<MemberActivationTokenResponse> createActivationToken() async {
    if (shouldFail) throw StateError(errorMessage ?? 'Failed to generate token');
    final token = 'token_${tokenCounter++}';
    return MemberActivationTokenResponse(
      activationToken: token,
      qrPayload: 'liftflow://member-activation/$token',
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      lifetimeSeconds: 60,
      gymId: '00000000-0000-0000-0000-00000000000a',
      gymName: 'Apex Performance Gym',
      gymSlug: 'apex-gym',
    );
  }

  @override
  Future<ValidatedGymActivation> validateActivationToken(String token) async {
    if (shouldFail) throw StateError(errorMessage ?? 'This QR code is not valid for LiftFlow.');
    return ValidatedGymActivation(
      valid: true,
      gymId: '00000000-0000-0000-0000-00000000000a',
      gymName: 'Apex Performance Gym',
      gymSlug: 'apex-gym',
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
    );
  }
}

void main() {
  group('Owner QR Member Activation Flow Tests', () {
    testWidgets('RegisterScreen (Step 1) validates inputs and proceeds without OTP dispatch', (tester) async {
      final fakeAuthRepo = FakeAuthRepository();
      final router = GoRouter(
        initialLocation: '/register',
        routes: [
          GoRoute(path: '/register', builder: (ctx, st) => const RegisterScreen()),
          GoRoute(
            path: '/verify-gym',
            builder: (ctx, st) {
              final extra = st.extra as Map<String, String>? ?? {};
              return Scaffold(
                body: Text('Verify Gym Page for ${extra['fullName']} (${extra['phone']})'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('Personal Details'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);

      // Empty submit validation
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter your full name.'), findsOneWidget);

      // Name only
      await tester.enterText(find.byType(TextField).at(0), 'John Athlete');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter a valid phone number (e.g. +91 98765 43210).'), findsOneWidget);

      // Valid phone -> Proceeds to Step 2 without any OTP prompt
      await tester.enterText(find.byType(TextField).at(1), '7019707247');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Gym Page for John Athlete (7019707247)'), findsOneWidget);
    });

    testWidgets('VerifyGymScreen (Step 2) validates QR and shows gym verified card', (tester) async {
      final fakeActivationRepo = FakeMemberActivationRepository();
      final router = GoRouter(
        initialLocation: '/verify-gym',
        routes: [
          GoRoute(
            path: '/verify-gym',
            builder: (ctx, st) => const VerifyGymScreen(
              fullName: 'John Athlete',
              phone: '+917019707247',
            ),
          ),
          GoRoute(
            path: '/account-setup',
            builder: (ctx, st) {
              final extra = st.extra as Map<String, String>? ?? {};
              return Scaffold(
                body: Text('Account Setup Page for ${extra['gymName']} with ${extra['activationToken']}'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            memberActivationRepositoryProvider.overrideWithValue(fakeActivationRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VERIFY GYM'), findsOneWidget);
      expect(find.text('Scan Gym Activation QR'), findsOneWidget);
      expect(find.text('ALIGN QR INSIDE FRAME'), findsOneWidget);
    });

    testWidgets('AccountSetupScreen (Step 3) validates credentials and registers with activation token', (tester) async {
      final fakeAuthRepo = FakeAuthRepository();
      final router = GoRouter(
        initialLocation: '/setup',
        routes: [
          GoRoute(
            path: '/setup',
            builder: (ctx, st) => const AccountSetupScreen(
              fullName: 'John Athlete',
              phone: '+917019707247',
              activationToken: 'test_token_secure_123',
              gymName: 'Apex Performance Gym',
            ),
          ),
          GoRoute(path: '/login', builder: (ctx, st) => const Scaffold(body: Text('Login Screen'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Login'), findsOneWidget);
      expect(find.textContaining('Apex Performance Gym'), findsOneWidget);

      // Empty submission
      await tester.tap(find.text('Complete Registration'));
      await tester.pump();
      expect(find.text('Please choose a username.'), findsOneWidget);

      // Mismatched passwords
      await tester.enterText(find.byType(TextField).at(0), 'johnathlete');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.enterText(find.byType(TextField).at(2), 'mismatch');
      await tester.tap(find.text('Complete Registration'));
      await tester.pump();
      expect(find.text('Passwords do not match. Please re-enter.'), findsOneWidget);

      // Matching passwords
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Complete Registration'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(fakeAuthRepo.registered, true);
      expect(fakeAuthRepo.registeredToken, 'test_token_secure_123');
      expect(fakeAuthRepo.registeredUsername, 'johnathlete');
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('OwnerActivationQrScreen renders QR code, timer, and handles refresh', (tester) async {
      final fakeActivationRepo = FakeMemberActivationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            memberActivationRepositoryProvider.overrideWithValue(fakeActivationRepo),
          ],
          child: const MaterialApp(
            home: OwnerActivationQrScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTIVATE NEW MEMBER'), findsOneWidget);
      expect(find.text('Scan to Join'), findsOneWidget);
      expect(find.text('Apex Performance Gym'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('Expires in'), findsOneWidget);
      expect(find.text('Refresh QR Code'), findsOneWidget);

      // Tap refresh
      await tester.tap(find.text('Refresh QR Code'));
      await tester.pumpAndSettle();

      expect(fakeActivationRepo.tokenCounter, 3); // initial (1->2) + refresh (2->3)
    });
  });
}
