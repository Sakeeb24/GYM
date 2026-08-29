// lib/features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_colors.dart';
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
      // Router guard will redirect to /app on successful auth state change.
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withAlpha(24),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.fitness_center_rounded, size: 32, color: AppColors.brand),
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: Text('LiftFlow', style: AppTypography.displayMedium)),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Welcome back',
                    style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 32),

                // Username field
                AppTextField(
                  controller: _username,
                  label: 'Username',
                  keyboard: TextInputType.text,
                  hint: 'Enter your username',
                ),
                const SizedBox(height: 12),

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
                const SizedBox(height: 4),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please contact your gym administrator to reset your password.',
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.brand),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login_rounded, size: 18),
                ),

                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),

                // Create Account button
                AppButton(
                  text: 'Create Account',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.push('/register'),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'New to LiftFlow? Register with your gym-provided phone number.',
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
