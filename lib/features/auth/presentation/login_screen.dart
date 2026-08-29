// lib/features/auth/presentation/login_screen.dart
// Athletic Gym Login Screen — LiftFlow
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final username = _username.text.trim();
    final password = _password.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your username and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final actions = ref.read(authActionsProvider);
      await actions.signInWithUsername(username, password);
      // Router guard handles redirection on authStateProvider update.
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Invalid username or password. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gym / Fitness Emblem
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Subtle glowing outer ring
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt,
                          border: Border.all(
                            color: isDark ? AppColors.brand.withAlpha(80) : AppColors.brandDark.withAlpha(80),
                            width: 2,
                          ),
                          boxShadow: isDark ? AppShadows.cyanGlow : AppShadows.sm,
                        ),
                      ),
                      // Core dumbbell icon
                      Icon(
                        Icons.fitness_center_rounded,
                        size: 40,
                        color: isDark ? AppColors.brand : AppColors.brandDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Brand Name
                Center(
                  child: Text(
                    'LIFTFLOW',
                    style: AppTypography.displayLarge.copyWith(
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Athletic Slogan
                Center(
                  child: Text(
                    'TRAIN • TRACK • TRANSFORM',
                    style: AppTypography.labelAthletic.copyWith(
                      color: isDark ? AppColors.brand : AppColors.brandDark,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Main Credential Card
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline, width: 1),
                    boxShadow: isDark ? AppShadows.cardElevation : AppShadows.md,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(
                        'ATHLETE SIGN IN',
                        style: AppTypography.labelAthletic.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Welcome back',
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),

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
                        obscure: _obscurePassword,
                        hint: 'Enter your password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please contact your gym administrator to reset your password.'),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark ? AppColors.brand : AppColors.brandDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Error banner
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withAlpha(100)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Sign In button
                      AppButton(
                        text: 'Sign In',
                        onPressed: _loading ? null : _signIn,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.bolt_rounded, size: 18),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: cs.outline)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'NEW ATHLETE?',
                        style: AppTypography.labelAthletic.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: cs.outline)),
                  ],
                ),

                const SizedBox(height: 20),

                // Create Account button
                AppButton(
                  text: 'Create Account',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.push('/register'),
                  icon: const Icon(Icons.card_membership_rounded, size: 18),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Register with the phone number provided to your gym.',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
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
