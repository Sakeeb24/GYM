// lib/features/auth/presentation/login_screen.dart
// Clean, Minimal Modern Fitness Login Screen (Apex Precision)
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _localError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    final u = _username.text.trim();
    final p = _password.text; // Do NOT trim password

    if (u.isEmpty || p.isEmpty) {
      setState(() => _localError = 'Please enter your username and password.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authActionsProvider).signInWithUsername(u, p);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // ── 1. Clean LiftFlow Dumbbell Logo ─────────────────
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        size: 28,
                        color: isDark ? AppColors.brand : AppColors.brandDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 2. Brand Name & Subtitle ─────────────────────────
                  Center(
                    child: Text(
                      'LIFTFLOW',
                      style: AppTypography.labelAthletic.copyWith(
                        fontSize: 22,
                        letterSpacing: 3.5,
                        color: isDark ? AppColors.brand : AppColors.brandDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'GYM MANAGEMENT PLATFORM',
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 3. Username Field ────────────────────────────────
                  AppTextField(
                    label: 'Username',
                    controller: _username,
                    hint: 'e.g. alex_runner',
                  ),
                  const SizedBox(height: 16),

                  // ── 4. Password Field ────────────────────────────────
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscure: _obscure,
                    hint: 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── 5. Forgot Password Link ──────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error Banner if present
                  if (_localError != null) ...[
                    AuthErrorBanner(message: _localError!),
                    const SizedBox(height: 16),
                  ],

                  // ── 6. Primary Action: SIGN IN ───────────────────────
                  AppButton(
                    text: _submitting ? 'Signing in...' : 'Sign In',
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
                  const SizedBox(height: 24),

                  // ── 7. Footer: Don't have an account? Create account ─
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/register'),
                          child: Text(
                            'Create account',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark ? AppColors.brand : AppColors.brandDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── 8. Footer: Owner gym setup link ─────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => context.push('/owner-register'),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Setting up a new gym? ',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Owner setup →',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark ? AppColors.brand : AppColors.brandDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
