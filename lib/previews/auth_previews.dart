// lib/previews/auth_previews.dart
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/verify_gym_screen.dart';
import '../features/auth/presentation/account_setup_screen.dart';
import '../features/auth/presentation/owner_activation_qr_screen.dart';
import '../features/auth/presentation/auth_widgets.dart';

Widget _wrapPreview(Widget child, {bool isDark = true}) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: child,
    ),
  );
}

@Preview(name: 'Login Screen (Dark)', group: 'Auth')
Widget previewLoginDark() => _wrapPreview(const LoginScreen(), isDark: true);

@Preview(name: 'Login Screen (Light)', group: 'Auth')
Widget previewLoginLight() => _wrapPreview(const LoginScreen(), isDark: false);

@Preview(name: 'Register Screen - Step 1 (Dark)', group: 'Auth')
Widget previewRegisterDark() => _wrapPreview(const RegisterScreen(), isDark: true);

@Preview(name: 'Register Screen - Step 1 (Light)', group: 'Auth')
Widget previewRegisterLight() => _wrapPreview(const RegisterScreen(), isDark: false);

@Preview(name: 'Verify Gym QR - Step 2 (Dark)', group: 'Auth')
Widget previewVerifyGymDark() => _wrapPreview(
  const VerifyGymScreen(fullName: 'Alex Johnson', phone: '+91 98765 43210'),
  isDark: true,
);

@Preview(name: 'Account Setup - Step 3 (Dark)', group: 'Auth')
Widget previewAccountSetupDark() => _wrapPreview(
  const AccountSetupScreen(
    fullName: 'Alex Johnson',
    phone: '+91 98765 43210',
    activationToken: 'sample_activation_token_123',
    gymName: 'Apex Performance Gym',
  ),
  isDark: true,
);

@Preview(name: 'Owner Activation QR Screen (Dark)', group: 'Auth')
Widget previewOwnerActivationDark() => _wrapPreview(
  const OwnerActivationQrScreen(),
  isDark: true,
);

@Preview(name: 'Step Indicator (Step 1 of 3)', group: 'Auth Components')
Widget previewStepIndicator1() => _wrapPreview(
  const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: AuthStepIndicator(current: 1, total: 3),
      ),
    ),
  ),
);

@Preview(name: 'Step Indicator (Step 2 of 3)', group: 'Auth Components')
Widget previewStepIndicator2() => _wrapPreview(
  const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: AuthStepIndicator(current: 2, total: 3),
      ),
    ),
  ),
);

@Preview(name: 'Step Indicator (Step 3 of 3)', group: 'Auth Components')
Widget previewStepIndicator3() => _wrapPreview(
  const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: AuthStepIndicator(current: 3, total: 3),
      ),
    ),
  ),
);

@Preview(name: 'Auth Error Banner', group: 'Auth Components')
Widget previewErrorBanner() => _wrapPreview(
  const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: AuthErrorBanner(message: 'Invalid username or password. Please try again.'),
      ),
    ),
  ),
);
