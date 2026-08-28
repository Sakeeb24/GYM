// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'business_rules/business_rules.dart';
import 'models/profile.dart';
import 'widgets/main_scaffold.dart';
import '../features/auth/auth_notifier.dart';
import '../features/auth/presentation/login_screen.dart';

class AppRouter {
  AppRouter._();

  static GoRouter create(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final profileAsync = ref.read(authStateProvider);
        final profile = profileAsync.valueOrNull;
        final loggingIn = state.subloc == '/login';
        if (profile == null) return loggingIn ? null : '/login';
        if (loggingIn) return '/app';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/app',
          name: 'app',
          pageBuilder: (context, state) {
            final profile = ref.read(authStateProvider).valueOrNull;
            if (profile == null) {
              return const NoTransitionPage(child: SizedBox.shrink());
            }
            return NoTransitionPage(
              child: MainScaffold(key: ValueKey(profile.role), role: profile.role),
            );
          },
        ),
      ],
      errorBuilder: (context, state) => Scaffold(body: Center(child: Text(state.error.toString()))),
    );
  }
}
