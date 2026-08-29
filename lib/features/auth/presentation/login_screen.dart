// lib/features/auth/presentation/login_screen.dart
// Clean, Minimal Modern Fitness Login Screen (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
    final p = _password.text.trim();

    if (u.isEmpty || p.isEmpty) {
      setState(() => _localError = 'Please enter your username and password.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authActionsProvider).signInWithUsername(u, p);
    } catch (e) {
      if (mounted) {
        setState(() => _localError = e.toString().replaceAll('Exception: ', ''));
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
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Your fitness. Your progress.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 3. Username Field ────────────────────────────────
                  AppTextField(
                    controller: _username,
                    label: 'Username',
                    keyboard: TextInputType.text,
                    hint: 'Enter your username',
                  ),
                  const SizedBox(height: 14),

                  // ── 4. Password Field with Eye Icon ──────────────────
                  AppTextField(
                    controller: _password,
                    label: 'Password',
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please contact your gym front desk to reset your password.')),
                        );
                      },
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
