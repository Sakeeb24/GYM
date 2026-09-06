// test/features/auth/owner_register_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liftflow/features/auth/owner_registration_repository.dart';
import 'package:liftflow/features/auth/presentation/owner_register_screen.dart';

class FakeOwnerRegistrationRepository implements OwnerRegistrationRepository {
  bool registered = false;
  String? registeredGymName;
  String? registeredGymSlug;
  String? registeredUsername;
  String? registeredSecret;
  bool shouldFail = false;
  String? errorMessage;

  @override
  Future<OwnerRegistrationResult> registerOwner({
    required String gymName,
    required String gymSlug,
    required String fullName,
    required String phone,
    required String username,
    required String password,
    required String setupSecret,
  }) async {
    if (shouldFail) {
      throw StateError(errorMessage ?? 'Invalid setup code. Please contact LiftFlow support.');
    }
    registered = true;
    registeredGymName = gymName;
    registeredGymSlug = gymSlug;
    registeredUsername = username;
    registeredSecret = setupSecret;
    return OwnerRegistrationResult(
      userId: 'user_123',
      gymId: 'gym_123',
      gymName: gymName,
      gymSlug: gymSlug,
    );
  }
}

void main() {
  group('OwnerRegisterScreen QA Tests', () {
    testWidgets('Validates all fields, slug auto-derivation, and successful submission', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeOwnerRegistrationRepository();
      final router = GoRouter(
        initialLocation: '/owner-register',
        routes: [
          GoRoute(path: '/owner-register', builder: (ctx, st) => const OwnerRegisterScreen()),
          GoRoute(path: '/login', builder: (ctx, st) => const Scaffold(body: Text('Login Screen'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ownerRegistrationRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GYM SETUP'), findsOneWidget);
      expect(find.text('01 GYM DETAILS'), findsOneWidget);
      expect(find.text('02 YOUR ACCOUNT'), findsOneWidget);
      expect(find.text('03 AUTHORISATION'), findsOneWidget);

      // 1. Submit empty form
      await tester.tap(find.text('Create Gym & Account'));
      await tester.pump();
      expect(find.text('Gym name must be at least 2 characters.'), findsOneWidget);

      // 2. Fill Gym Name and verify slug auto-derivation
      await tester.enterText(find.widgetWithText(TextField, 'Gym Name'), 'Iron Forge Fitness');
      await tester.pump();
      expect(find.text('Handle: iron-forge-fitness'), findsOneWidget);

      // 3. Fill partial details & verify sequential validations
      await tester.tap(find.text('Create Gym & Account'));
      await tester.pump();
      expect(find.text('Please enter your full name (at least 2 characters).'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Shoaib Owner');
      await tester.tap(find.text('Create Gym & Account'));
      await tester.pump();
      expect(find.text('Please enter a valid phone number.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Phone Number'), '9449230359');
      await tester.tap(find.text('Create Gym & Account'));
      await tester.pump();
      expect(find.text('Username must be at least 3 characters.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'shoaib_owner');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'PasswordMismatch');
      await tester.tap(find.text('Create Gym & Account'));
      await tester.pump();
      expect(find.text('Passwords do not match. Please re-enter.'), findsOneWidget);

      // 4. Match passwords but missing setup code
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'Password123!');
      await tester.tap(find.text('Create Gym & Account'));
      await tester.pump();
      expect(find.text('Please enter the setup code provided by LiftFlow.'), findsOneWidget);

      // 5. Fill setup code and submit successfully
      await tester.enterText(find.widgetWithText(TextField, 'Setup Code'), 'SecretPass2026');
      await tester.tap(find.text('Create Gym & Account'));
      await tester.pump();
      expect(find.text('Gym Created!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pumpAndSettle();

      expect(fakeRepo.registered, true);
      expect(fakeRepo.registeredGymName, 'Iron Forge Fitness');
      expect(fakeRepo.registeredGymSlug, 'iron-forge-fitness');
      expect(fakeRepo.registeredUsername, 'shoaib_owner');
      expect(fakeRepo.registeredSecret, 'SecretPass2026');
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('Displays server-side rejection message when setup code is invalid', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeOwnerRegistrationRepository()..shouldFail = true;
      final router = GoRouter(
        initialLocation: '/owner-register',
        routes: [
          GoRoute(path: '/owner-register', builder: (ctx, st) => const OwnerRegisterScreen()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ownerRegistrationRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Gym Name'), 'Iron Forge');
      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Shoaib');
      await tester.enterText(find.widgetWithText(TextField, 'Phone Number'), '9449230359');
      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'shoaib_owner');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextField, 'Setup Code'), 'WrongCode');

      await tester.tap(find.text('Create Gym & Account'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid setup code. Please contact LiftFlow support.'), findsOneWidget);
    });
  });
}
