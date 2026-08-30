// lib/features/auth/presentation/account_setup_screen.dart
// Clean Registration Step 3: Username & Password Account Creation (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
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
    final p = _password.text; // Preserve exact untrimmed password
    final cp = _confirmPassword.text;

    if (u.isEmpty) {
      setState(() => _localError = 'Please choose a username.');
      return;
    }
    if (u.length < 3) {
      setState(() => _localError = 'Username must be at least 3 characters.');
      return;
    }
    if (p.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters.');
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
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localError = AppErrorMapper.toUserMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'CREATE CREDENTIALS',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthStepIndicator(current: 3, total: 3),
                  const SizedBox(height: 24),

                  if (_created) ...[
                    const SizedBox(height: 32),
                    const Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.brand,
                        child: Icon(Icons.check_rounded, size: 40, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Account Created!',
                        style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Redirecting you to sign in with your new credentials...',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ] else ...[
                    Text(
                      'Choose Your Login',
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You will use this username and password to log in. No SMS OTP will be required to log in.',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),

                    // Username
                    AppTextField(
                      label: 'Username',
                      controller: _username,
                      hint: 'e.g. alex_lift',
                    ),
                    const SizedBox(height: 16),

                    // Password
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      obscure: _obscure,
                      hint: 'Minimum 8 characters',
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
                      label: 'Confirm Password',
                      controller: _confirmPassword,
                      obscure: _obscure,
                      hint: 'Re-enter your password',
                    ),
                    const SizedBox(height: 16),

                    if (_localError != null) ...[
                      AuthErrorBanner(message: _localError!),
                      const SizedBox(height: 16),
                    ],

                    AppButton(
                      text: _submitting ? 'Creating account...' : 'Complete Registration',
                      onPressed: _submitting ? null : _submit,
                      fullWidth: true,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
