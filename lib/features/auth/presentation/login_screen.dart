// lib/features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_typography.dart';
import '../auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _otpMode = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final actions = ref.read(authActionsProvider);
    try {
      if (_otpMode) {
        await actions.signInWithOtp(_email.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Magic link sent.')));
      } else {
        await actions.signInWithEmail(_email.text.trim(), _password.text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.fitness_center, size: 28)),
              const SizedBox(height: 24),
              Text('LiftFlow', style: AppTypography.displayMedium),
              Text('Sign in to your gym', style: AppTypography.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              AppTextField(controller: _email, label: 'Email', keyboard: TextInputType.emailAddress),
              if (!_otpMode) ...[const SizedBox(height: 12), AppTextField(controller: _password, label: 'Password', obscure: true)],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: AppButton(text: _otpMode ? 'Send magic link' : 'Sign in', onPressed: _loading ? null : _signIn, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login))),
              const SizedBox(height: 12),
              TextButton(onPressed: () => setState(() => _otpMode = !_otpMode), child: Text(_otpMode ? 'Use password instead' : 'Use magic link')),
            ]),
          ),
        ),
      ),
    );
  }
}
