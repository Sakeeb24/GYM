// lib/features/auth/presentation/register_screen.dart
// Registration Step 1: Personal Details (Contact Information Only — No SMS OTP)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _localError = null);
    final name = _fullName.text.trim();
    final phone = _phone.text.trim();

    if (name.isEmpty) {
      setState(() => _localError = 'Please enter your full name.');
      return;
    }
    if (phone.isEmpty || phone.length < 8) {
      setState(() => _localError = 'Please enter a valid phone number (e.g. +91 98765 43210).');
      return;
    }

    // Step 1 Complete -> Proceed directly to Step 2 (QR Verification).
    // Phone number is recorded for gym contact records; NO SMS OTP is sent.
    context.push('/verify-gym', extra: {
      'fullName': name,
      'phone': phone,
    });
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
          'CREATE ACCOUNT',
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
                  const AuthStepIndicator(current: 1, total: 3),
                  const SizedBox(height: 24),

                  Text(
                    'Personal Details',
                    style: AppTypography.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step 1 of 3: Enter your name and contact phone number.',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  AppTextField(
                    controller: _fullName,
                    label: 'Full Name',
                    hint: 'e.g. Alex Johnson',
                    keyboard: TextInputType.name,
                  ),
                  const SizedBox(height: 14),

                  AppTextField(
                    controller: _phone,
                    label: 'Phone Number',
                    hint: '+91 98765 43210',
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),

                  if (_localError != null) ...[
                    AuthErrorBanner(message: _localError!),
                    const SizedBox(height: 16),
                  ],

                  AppButton(
                    text: 'Continue',
                    onPressed: _submit,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          ),
                          Text(
                            'Sign In',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark ? AppColors.brand : AppColors.brandDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
