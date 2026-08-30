// lib/features/auth/presentation/otp_screen.dart
// Clean Registration Step 2: Phone OTP Verification (Apex Precision)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../auth_notifier.dart';
import '../auth_repository.dart';
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
          'VERIFY PHONE',
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
                  const AuthStepIndicator(current: 2, total: 3),
                  const SizedBox(height: 24),

                  Text(
                    'Enter Verification Code',
                    style: AppTypography.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step 2 of 3: We sent a 6-digit code to ${widget.phone}',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  if (SupabaseAuthRepository.isTestPhone(widget.phone)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.brand : AppColors.brandDark).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isDark ? AppColors.brand : AppColors.brandDark).withAlpha(80),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Test Phone: Use code 123456',
                              style: AppTypography.bodySmall.copyWith(
                                color: isDark ? AppColors.brand : AppColors.brandDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _otp.text = '123456';
                              setState(() {});
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Fill 123456', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  AppTextField(
                    controller: _otp,
                    label: '6-Digit Code',
                    hint: '123456',
                    keyboard: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _countdown > 0 ? 'Resend in ${_countdown}s' : 'Didn\'t receive code?',
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: _countdown == 0 ? _resend : null,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          'Resend Code',
                          style: TextStyle(
                            color: _countdown == 0
                                ? (isDark ? AppColors.brand : AppColors.brandDark)
                                : cs.onSurfaceVariant.withAlpha(100),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_localError != null) ...[
                    AuthErrorBanner(message: _localError!),
                    const SizedBox(height: 16),
                  ],

                  AppButton(
                    text: 'Verify & Continue',
                    onPressed: _verify,
                    fullWidth: true,
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
