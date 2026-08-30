// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/main_scaffold.dart';
import '../features/auth/auth_notifier.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/account_setup_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';

/// Routes accessible without authentication.
const _publicRoutes = {'/login', '/register', '/otp', '/account-setup', '/forgot-password'};

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(WidgetRef ref) {
    ref.listen(authStateProvider, (prev, next) => notifyListeners());
  }
}

class AppRouter {
  AppRouter._();

  static GoRouter create(WidgetRef ref) {
    final notifier = _RouterNotifier(ref);

    return GoRouter(
      initialLocation: '/login',
      refreshListenable: notifier,
      redirect: (context, state) {
        final profileAsync = ref.read(authStateProvider);
        final profile = profileAsync.valueOrNull;
        final currentPath = state.uri.path;
        final isPublic = _publicRoutes.contains(currentPath);

        if (profile == null) {
          return isPublic ? null : '/login';
        }
        // Authenticated: redirect away from public routes.
        if (isPublic) return '/app';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          name: 'forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),

        // ── Registration flow (3 steps) ───────────────────────────────────
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/otp',
          name: 'otp',
          builder: (context, state) {
            final extra = state.extra as Map<String, String>? ?? {};
            return OtpScreen(
              fullName: extra['fullName'] ?? extra['full_name'] ?? '',
              phone: extra['phone'] ?? '',
            );
          },
        ),
        GoRoute(
          path: '/account-setup',
          name: 'account-setup',
          builder: (context, state) {
            final extra = state.extra as Map<String, String>? ?? {};
            return AccountSetupScreen(
              fullName: extra['fullName'] ?? extra['full_name'] ?? '',
              phone: extra['phone'] ?? '',
              otpToken: extra['otpToken'] ?? extra['otp_token'] ?? '',
            );
          },
        ),

        // ── Authenticated shell ───────────────────────────────────────────
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
      errorBuilder: (context, state) => Scaffold(
        body: Center(child: Text(state.error.toString())),
      ),
    );
  }
}
