// test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liftflow/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders fields and toggles OTP mode', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify initial password mode
    expect(find.text('Sign in to your gym'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Use magic link'), findsOneWidget);

    // Toggle to OTP mode
    await tester.tap(find.text('Use magic link'));
    await tester.pump();

    // Password field should be hidden, OTP text shown
    expect(find.text('Password'), findsNothing);
    expect(find.text('Send magic link'), findsOneWidget);
    expect(find.text('Use password instead'), findsOneWidget);

    // Toggle back to password mode
    await tester.tap(find.text('Use password instead'));
    await tester.pump();

    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
