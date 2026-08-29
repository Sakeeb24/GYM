// lib/features/auth/presentation/otp_screen.dart
// Registration Step 2: Phone OTP Verification
import 'dart:async';
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

class OtpScreen extends ConsumerStatefulWidget {
  final String fullName;
  final String phone;

  const OtpScreen({
    super.key,
    required this.fullName,
    required this.phone,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otp = TextEditingController();
  String? _localError;
  int _countdown = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _countdown = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) {
        if (mounted) setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otp.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    setState(() => _localError = null);
    try {
      await ref.read(authActionsProvider).sendPhoneOtp(widget.phone);
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new 6-digit verification code has been sent.')),
        );
      }
    } catch (e) {
      setState(() => _localError = e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _verify() {
    setState(() => _localError = null);
    final token = _otp.text.trim();
    if (token.length != 6) {
      setState(() => _localError = 'Please enter the complete 6-digit verification code.');
      return;
    }

    context.push('/account-setup', extra: {
      'fullName': widget.fullName,
      'phone': widget.phone,
      'otpToken': token,
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
          'PHONE VERIFICATION',
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
                  const AuthStepIndicator(current: 2, total: 3),
                  const SizedBox(height: 32),

                  // Header
                  Text(
                    'VERIFY PHONE',
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the 6-digit code sent to ${widget.phone}',
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
                          '02 ONE-TIME CODE (OTP)',
                          style: AppTypography.labelAthletic.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // OTP Text Field
                        AppTextField(
                          controller: _otp,
                          label: 'Verification Code',
                          hint: '6-digit OTP',
                          keyboard: TextInputType.number,
                          maxLength: 6,
                          suffixIcon: Icon(
                            Icons.lock_clock_outlined,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Resend Countdown Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _countdown > 0 ? 'Resend in ${_countdown}s' : 'Didn\'t receive code?',
                              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                            TextButton(
                              onPressed: _countdown == 0 ? _resend : null,
                              child: Text(
                                'Resend Code',
                                style: AppTypography.labelAthletic.copyWith(
                                  color: _countdown == 0
                                      ? (isDark ? AppColors.brand : AppColors.brandDark)
                                      : cs.onSurfaceVariant.withAlpha(100),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Error Banner
                        if (_localError != null) ...[
                          AuthErrorBanner(message: _localError!),
                          const SizedBox(height: 16),
                        ],

                        // Verify & Continue Button
                        AppButton(
                          text: 'VERIFY & CONTINUE',
                          onPressed: _verify,
                          fullWidth: true,
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
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
