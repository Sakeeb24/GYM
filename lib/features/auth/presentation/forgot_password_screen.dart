// lib/features/auth/presentation/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../auth_notifier.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1; // 1 = enter username, 2 = enter OTP + new password
  bool _loading = false;
  String? _error;
  String? _maskedPhone;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter your username');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final masked = await repo.requestPasswordReset(username);
      if (!mounted) return;
      setState(() {
        _step = 2;
        _maskedPhone = masked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toUserMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _handleResetPassword() async {
    final username = _usernameController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (otp.length < 6) {
      setState(() => _error = 'Please enter the 6-digit verification code');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.completePasswordReset(
        username: username,
        otpToken: otp,
        newPassword: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully! Please log in.'),
          backgroundColor: AppColors.brand,
        ),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toUserMessage(e);
        _loading = false;
      });
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
          onPressed: () {
            if (_step == 2) {
              setState(() => _step = 1);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          'RESET PASSWORD',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 28,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _step == 1 ? 'Find Your Account' : 'Verify & Set Password',
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _step == 1
                    ? 'Enter your username to receive a security verification code on your registered phone.'
                    : 'Enter the code sent to $_maskedPhone and choose a new password.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: AppRadii.r8,
                    border: Border.all(color: AppColors.error.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_step == 1) ...[
                AppTextField(
                  label: 'Username',
                  controller: _usernameController,
                  hint: 'Enter your LiftFlow username',
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: _loading ? 'Sending code...' : 'Send Verification Code',
                  fullWidth: true,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : null,
                  onPressed: _loading ? null : _handleRequestOtp,
                ),
              ] else ...[
                AppTextField(
                  label: '6-Digit Verification Code',
                  controller: _otpController,
                  hint: '123456',
                  keyboard: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'New Password',
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  hint: 'Minimum 8 characters',
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Confirm New Password',
                  controller: _confirmPasswordController,
                  obscure: _obscurePassword,
                  hint: 'Re-enter your new password',
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: _loading ? 'Updating password...' : 'Update Password',
                  fullWidth: true,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : null,
                  onPressed: _loading ? null : _handleResetPassword,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
