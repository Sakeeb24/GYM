// test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liftflow/features/auth/presentation/login_screen.dart';

Widget buildLoginSubject() {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, st) => const Scaffold(body: Text('Register'))),
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
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
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

    final createBtn = find.text('Create Account');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    expect(find.text('Register'), findsOneWidget);
  });
}
