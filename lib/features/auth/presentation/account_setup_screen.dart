// lib/features/auth/presentation/account_setup_screen.dart
// Registration Step 3: Username & Password Account Creation
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../auth_notifier.dart';
import 'auth_widgets.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  final String fullName;
  final String phone;
  final String otpToken;

  const AccountSetupScreen({
    super.key,
    required this.fullName,
    required this.phone,
    required this.otpToken,
  });

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscure = true;
  String? _localError;
  bool _submitting = false;
  bool _created = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    final u = _username.text.trim().toLowerCase();
    final p = _password.text.trim();
    final cp = _confirmPassword.text.trim();

    if (u.isEmpty) {
      setState(() => _localError = 'Please choose a username.');
      return;
    }
    if (u.length < 3) {
      setState(() => _localError = 'Username must be at least 3 characters.');
      return;
    }
    if (p.length < 6) {
      setState(() => _localError = 'Password must be at least 6 characters.');
      return;
    }
    if (p != cp) {
      setState(() => _localError = 'Passwords do not match. Please re-enter.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authActionsProvider).registerMember(
            fullName: widget.fullName,
            phone: widget.phone,
            otpToken: widget.otpToken,
            username: u,
            password: p,
          );

      setState(() => _created = true);

      // Brief celebration pause before directing to login
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      setState(() => _localError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'ACCOUNT CREATION',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Indicator
                  const AuthStepIndicator(current: 3, total: 3),
                  const SizedBox(height: 32),

                  // Header
                  Text(
                    'CREATE CREDENTIALS',
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set your athlete login username and password.',
                    style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),

                  // Form Container
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: AppRadii.r16,
                      border: Border.all(color: cs.outline),
                      boxShadow: isDark ? AppShadows.cardElevation : AppShadows.md,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '03 SECURE ACCESS',
                          style: AppTypography.labelAthletic.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Username
                        AppTextField(
                          controller: _username,
                          label: 'Athlete Username',
                          hint: 'e.g. alex_lift',
                          keyboard: TextInputType.text,
                          suffixIcon: Icon(
                            Icons.alternate_email_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        AppTextField(
                          controller: _password,
                          label: 'Password',
                          hint: 'Minimum 6 characters',
                          obscure: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        AppTextField(
                          controller: _confirmPassword,
                          label: 'Confirm Password',
                          hint: 'Re-enter your password',
                          obscure: _obscure,
                          suffixIcon: Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Success Celebration State
                        if (_created) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.success, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ACCOUNT CREATED',
                                        style: AppTypography.labelAthletic.copyWith(
                                          color: AppColors.success,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Welcome to LiftFlow! Redirecting to sign in...',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: cs.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Error Banner
                        if (_localError != null) ...[
                          AuthErrorBanner(message: _localError!),
                          const SizedBox(height: 16),
                        ],

                        // Finish & Create Account Button
                        AppButton(
                          text: _submitting ? 'CREATING ACCOUNT...' : (_created ? 'SUCCESS!' : 'FINISH & CREATE ACCOUNT'),
                          onPressed: (_submitting || _created) ? null : _submit,
                          fullWidth: true,
                          variant: _created ? AppButtonVariant.gold : AppButtonVariant.filled,
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.fitness_center_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
