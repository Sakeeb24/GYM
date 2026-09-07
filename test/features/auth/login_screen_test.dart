// test/features/auth/login_screen_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liftflow/core/business_rules/business_rules.dart';
import 'package:liftflow/core/models/profile.dart';
import 'package:liftflow/core/router.dart';
import 'package:liftflow/features/auth/auth_notifier.dart';
import 'package:liftflow/features/auth/auth_repository.dart';
import 'package:liftflow/features/auth/presentation/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository implements AuthRepository {
  final StreamController<Profile?> _profileController = StreamController<Profile?>.broadcast();
  Profile? _currentProfile;
  bool shouldFailSignIn = false;
  Exception? signInException;

  void emitProfile(Profile? profile) {
    _currentProfile = profile;
    _profileController.add(profile);
  }

  @override
  Stream<AuthState> authState() => const Stream.empty();

  @override
  Future<void> signInWithUsername(String username, String password) async {
    if (shouldFailSignIn) {
      throw signInException ?? const AuthException('Invalid login credentials');
    }
    final profile = Profile(
      userId: 'user_12345',
      gymId: 'gym_12345',
      role: AppRole.owner,
      username: username,
      fullName: 'Apex Owner',
    );
    emitProfile(profile);
  }

  @override
  Future<void> registerMember({
    required String fullName,
    required String phone,
    required String activationToken,
    required String username,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    emitProfile(null);
  }

  @override
  Future<Profile?> currentProfile() async => _currentProfile;

  @override
  Stream<Profile?> watchProfile() => _profileController.stream;

  @override
  Future<bool> isUsernameTaken(String username) async => false;

  @override
  Future<String> requestPasswordReset(String username) async => '***';

  @override
  Future<void> completePasswordReset({
    required String username,
    required String otpToken,
    required String newPassword,
  }) async {}

  void dispose() {
    _profileController.close();
  }
}

Widget buildLoginSubject() {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, st) => const Scaffold(body: Text('Register'))),
      GoRoute(path: '/forgot-password', builder: (ctx, st) => const Scaffold(body: Text('Forgot Password Screen'))),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('LoginScreen renders username and password fields', (tester) async {
    await tester.pumpWidget(buildLoginSubject());
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('LIFTFLOW'), findsOneWidget);
    expect(find.text('GYM MANAGEMENT PLATFORM'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('LoginScreen shows error when fields are empty on sign-in', (tester) async {
    await tester.pumpWidget(buildLoginSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Please enter your username and password.'), findsOneWidget);
  });

  testWidgets('LoginScreen navigates to /register on Create Account tap', (tester) async {
    await tester.pumpWidget(buildLoginSubject());
    await tester.pumpAndSettle();

    final createBtn = find.text('Create account');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('LoginScreen navigates to /forgot-password on Forgot password tap', (tester) async {
    await tester.pumpWidget(buildLoginSubject());
    await tester.pumpAndSettle();

    final forgotBtn = find.text('Forgot password?');
    await tester.ensureVisible(forgotBtn);
    await tester.tap(forgotBtn);
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password Screen'), findsOneWidget);
  });

  testWidgets('Valid username + password triggers authentication and navigates to /app dashboard', (tester) async {
    final mockRepo = MockAuthRepository();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(mockRepo.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Starts on Splash -> auto routes to /login when unauthenticated
    expect(find.text('Sign In'), findsOneWidget);

    // Enter valid credentials
    await tester.enterText(find.byType(TextField).at(0), 'apex_owner');
    await tester.enterText(find.byType(TextField).at(1), 'Password123!');

    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Router must navigate to authenticated /app dashboard
    expect(find.text('Sign In'), findsNothing);
    expect(find.text('LIFTFLOW'), findsWidgets);
  });

  testWidgets('Invalid password displays user-friendly error message on login screen', (tester) async {
    final mockRepo = MockAuthRepository()
      ..shouldFailSignIn = true
      ..signInException = const AuthException('Invalid login credentials');

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(mockRepo.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'apex_owner');
    await tester.enterText(find.byType(TextField).at(1), 'WrongPassword!');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid username or password. Please try again.'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Unauthenticated user navigating to protected route is redirected to /login', (tester) async {
    final mockRepo = MockAuthRepository();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(mockRepo.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    router.go('/app');
    await tester.pumpAndSettle();

    // Because user is not authenticated, must redirect back to /login
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Logout clears session and redirects to /login', (tester) async {
    final mockRepo = MockAuthRepository();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(mockRepo.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Sign in
    await tester.enterText(find.byType(TextField).at(0), 'apex_owner');
    await tester.enterText(find.byType(TextField).at(1), 'Password123!');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsNothing);

    // 2. Sign out
    await container.read(authActionsProvider).signOut();
    await tester.pumpAndSettle();

    // Must be back on login screen
    expect(find.text('Sign In'), findsOneWidget);
  });
}

