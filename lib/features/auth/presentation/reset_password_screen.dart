// lib/features/auth/presentation/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../auth_notifier.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _updated = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _hasActiveRecoverySession() {
    try {
      return AppSupabase.client.auth.currentSession != null;
    } catch (_) {
      return true; // Fallback for test environments
    }
  }

  Future<void> _handleUpdatePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.isEmpty) {
      setState(() => _error = 'Please enter your new password.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match. Please re-enter.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authActionsProvider).updatePassword(password);
      // Sign out recovery session so the user signs in fresh
      await ref.read(authActionsProvider).signOut();
      if (!mounted) return;
      setState(() {
        _updated = true;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSession = _hasActiveRecoverySession();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
        title: Text(
          'RESET YOUR PASSWORD',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
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
                      child: Icon(
                        _updated ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
                        size: 28,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_updated) ...[
                    // ── Success State ─────────────────────────────────
                    Text(
                      'Password Updated Successfully',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your password has been changed. You can now sign in with your new password.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      text: 'Go to Login',
                      fullWidth: true,
                      onPressed: () => context.go('/login'),
                    ),
                  ] else if (!hasSession) ...[
                    // ── Invalid / Expired Link Safeguard ───────────────
                    Text(
                      'Invalid or Expired Link',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This password reset link is invalid, expired, or has already been used. Please request a new link.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      text: 'Request New Reset Link',
                      fullWidth: true,
                      onPressed: () => context.go('/forgot-password'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(
                          'Back to Login',
                          style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // ── Set New Password Form ───────────────────────────
                    Text(
                      'Set New Password',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a strong password with at least 8 characters.',
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

                    AppTextField(
                      label: 'New Password',
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      hint: 'Minimum 8 characters',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      label: 'Confirm Password',
                      controller: _confirmPasswordController,
                      obscure: _obscurePassword,
                      hint: 'Re-enter your new password',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleUpdatePassword(),
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
                      onPressed: _loading ? null : _handleUpdatePassword,
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
