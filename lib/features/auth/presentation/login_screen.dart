// lib/features/auth/presentation/login_screen.dart
// Premium Athletic Login Experience — Username + Password Authentication
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Gym / Strength Emblem with Barbell Geometry ───
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Geometric background lines
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt,
                            border: Border.all(
                              color: isDark ? AppColors.brand.withAlpha(90) : AppColors.brandDark.withAlpha(90),
                              width: 2,
                            ),
                            boxShadow: isDark ? AppShadows.cyanGlow : AppShadows.sm,
                          ),
                        ),
                        // Inner plate ring
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.brand.withAlpha(50) : AppColors.brandDark.withAlpha(50),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Fitness icon
                        Icon(
                          Icons.fitness_center_rounded,
                          size: 42,
                          color: isDark ? AppColors.brand : AppColors.brandDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 2. Brand Typography ──────────────────────────────
                  Center(
                    child: Text(
                      'LIFTFLOW',
                      style: AppTypography.displayLarge.copyWith(
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── 3. Three-line Fitness Slogan ──────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Text(
                        'TRAIN.  TRACK.  TRANSFORM.',
                        style: AppTypography.labelAthletic.copyWith(
                          color: isDark ? AppColors.brand : AppColors.brandDark,
                          letterSpacing: 2.0,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 4. Main Authentication Card ──────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: AppRadii.r16,
                      border: Border.all(color: cs.outline, width: 1),
                      boxShadow: isDark ? AppShadows.cardElevation : AppShadows.md,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ATHLETE SIGN IN',
                          style: AppTypography.labelAthletic.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Welcome back',
                          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),

                        // Username field
                        AppTextField(
                          controller: _username,
                          label: 'Username',
                          keyboard: TextInputType.text,
                          hint: 'Enter your username',
                          suffixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password field
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
                        const SizedBox(height: 12),

                        // Forgot Password Link
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Contact your gym front desk to reset your password.'),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: AppTypography.bodySmall.copyWith(
                                color: isDark ? AppColors.brand : AppColors.brandDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner
                        if (_localError != null) ...[
                          AuthErrorBanner(message: _localError!),
                          const SizedBox(height: 16),
                        ],

                        // Sign In Button
                        AppButton(
                          text: _submitting ? 'Authenticating...' : 'Sign In',
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

                  // ── 5. Create Account / Register Footer ───────────────
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          'Create Account',
                          style: AppTypography.labelLarge.copyWith(
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
