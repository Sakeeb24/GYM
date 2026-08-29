// lib/features/auth/presentation/otp_screen.dart
// Athletic Registration Step 2 — Phone OTP Verification
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../auth_notifier.dart';
import 'auth_widgets.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String fullName;
  final String phone;

  const OtpScreen({super.key, required this.fullName, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  String? _error;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    if (mounted) {
      context.push('/account-setup', extra: {
        'full_name': widget.fullName,
        'phone': widget.phone,
        'otp_token': otp,
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final actions = ref.read(authActionsProvider);
      await actions.sendPhoneOtp(widget.phone);
      _startCountdown();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to resend OTP. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maskedPhone = widget.phone.length > 4
        ? '${widget.phone.substring(0, widget.phone.length - 4)}****'
        : widget.phone;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'SECURITY VERIFICATION',
          style: AppTypography.labelAthletic.copyWith(
            color: isDark ? AppColors.brand : AppColors.brandDark,
            fontSize: 12,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthStepIndicator(current: 2, total: 3),
                const SizedBox(height: 28),

                // Shield / Verification Icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.brand.withAlpha(80) : AppColors.brandDark.withAlpha(80),
                        width: 1.5,
                      ),
                      boxShadow: isDark ? AppShadows.cyanGlow : AppShadows.sm,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 34,
                      color: isDark ? AppColors.brand : AppColors.brandDark,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Center(
                  child: Text(
                    'VERIFY YOUR NUMBER',
                    style: AppTypography.displaySmall.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Enter the 6-digit verification code sent to $maskedPhone',
                    style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // 6-digit OTP Box Row
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline, width: 1),
                    boxShadow: isDark ? AppShadows.cardElevation : AppShadows.md,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _OtpBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      onChanged: (val) {
                        if (val.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        } else if (val.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        setState(() {});
                      },
                    )),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBanner(message: _error!),
                ],

                const SizedBox(height: 28),

                AppButton(
                  text: 'Verify Code',
                  onPressed: (_loading || _otp.length < 6) ? null : _verify,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.verified_rounded, size: 18),
                ),

                const SizedBox(height: 20),
                Center(
                  child: _secondsLeft > 0
                      ? Text(
                          'Resend code in ${_secondsLeft}s',
                          style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _resending ? null : _resend,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(
                            'Resend Code',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark ? AppColors.brand : AppColors.brandDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTypography.metricSmall.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w800,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.outline, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? AppColors.brand : AppColors.brandDark,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
