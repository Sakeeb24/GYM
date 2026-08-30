// lib/features/auth/presentation/register_screen.dart
// Clean Registration Step 1: Personal Profile (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_notifier.dart';
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
  bool _submitting = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

    setState(() => _submitting = true);
    try {
      await ref.read(authActionsProvider).sendPhoneOtp(phone);

      if (mounted) {
        context.push('/otp', extra: {
          'fullName': name,
          'phone': phone,
        });
      }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
      if (e is AuthApiException) {
        msg = e.message;
      }
      setState(() => _localError = msg);
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
                    'Step 1 of 3: Enter your name and mobile number.',
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
                    text: _submitting ? 'Sending code...' : 'Continue',
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
                  const SizedBox(height: 20),

                  Center(
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          children: [
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: isDark ? AppColors.brand : AppColors.brandDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
