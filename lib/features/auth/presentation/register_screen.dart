// lib/features/auth/presentation/register_screen.dart
// Registration Step 1: Personal Profile
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
          'NEW ATHLETE REGISTRATION',
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
                  // Step Progress Indicator
                  const AuthStepIndicator(current: 1, total: 3),
                  const SizedBox(height: 32),

                  // Header
                  Text(
                    'START YOUR JOURNEY',
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Build your profile. Build your strength.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark ? AppColors.brand : AppColors.brandDark,
                      fontWeight: FontWeight.w600,
                    ),
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
                          '01 PERSONAL DETAILS',
                          style: AppTypography.labelAthletic.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Full Name
                        AppTextField(
                          controller: _fullName,
                          label: 'Full Name',
                          hint: 'e.g. Alex Johnson',
                          keyboard: TextInputType.name,
                          suffixIcon: Icon(
                            Icons.badge_outlined,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Phone Number
                        AppTextField(
                          controller: _phone,
                          label: 'Phone Number',
                          hint: '+91 98765 43210',
                          keyboard: TextInputType.phone,
                          suffixIcon: Icon(
                            Icons.phone_outlined,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner
                        if (_localError != null) ...[
                          AuthErrorBanner(message: _localError!),
                          const SizedBox(height: 16),
                        ],

                        // Send OTP Button
                        AppButton(
                          text: _submitting ? 'SENDING OTP...' : 'CONTINUE TO VERIFICATION',
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
                              : const Icon(Icons.arrow_forward_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign In Alternate Link
                  Center(
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an athlete account? ',
                          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          children: [
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: isDark ? AppColors.brand : AppColors.brandDark,
                                fontWeight: FontWeight.w800,
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
