// lib/features/auth/presentation/account_setup_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_colors.dart';
import '../auth_notifier.dart';
import 'auth_widgets.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  final String fullName;
  final String phone;
  final String otpToken;

  const AccountSetupScreen({
    super.key,
    required this.fullName,
    required this.phone,
    required this.otpToken,
  });

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _usernameError;
  bool _usernameAvailable = false;
  bool _checkingUsername = false;
  Timer? _debounce;

  static final _usernameRe = RegExp(r'^[a-z0-9_]{3,30}$');

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim().toLowerCase();

    if (trimmed.isEmpty) {
      setState(() { _usernameError = null; _usernameAvailable = false; });
      return;
    }
    if (!_usernameRe.hasMatch(trimmed)) {
      setState(() {
        _usernameError = '3-30 chars; lowercase letters, numbers, underscores only.';
        _usernameAvailable = false;
      });
      return;
    }
    setState(() { _usernameError = null; _checkingUsername = true; _usernameAvailable = false; });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final actions = ref.read(authActionsProvider);
      try {
        final taken = await actions.isUsernameTaken(trimmed);
        if (mounted) {
          setState(() {
            _usernameError = taken ? 'Username is already taken.' : null;
            _usernameAvailable = !taken;
            _checkingUsername = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  String? _validatePassword(String pass) {
    if (pass.length < 8) return 'Password must be at least 8 characters.';
    if (!pass.contains(RegExp(r'[A-Za-z]'))) return 'Password must include at least one letter.';
    if (!pass.contains(RegExp(r'[0-9]'))) return 'Password must include at least one number.';
    return null;
  }

  Future<void> _completeRegistration() async {
    final username = _username.text.trim().toLowerCase();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;

    if (username.isEmpty || !_usernameAvailable) {
      setState(() => _error = 'Please choose a valid, available username.');
      return;
    }
    final passErr = _validatePassword(password);
    if (passErr != null) { setState(() => _error = passErr); return; }
    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match.'); return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final actions = ref.read(authActionsProvider);
      await actions.registerMember(
        fullName: widget.fullName,
        phone: widget.phone,
        otpToken: widget.otpToken,
        username: username,
        password: password,
      );
      if (mounted) {
        while (context.canPop()) {
          context.pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please sign in with your new username.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Bad state: ', '').replaceAll('Exception:', '').trim());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget usernameStatus;
    if (_checkingUsername) {
      usernameStatus = const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_usernameAvailable) {
      usernameStatus = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20);
    } else {
      usernameStatus = const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Set Up Account'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthStepIndicator(current: 3, total: 3),
              const SizedBox(height: 28),

              Text('Choose Credentials', style: AppTypography.headlineLarge),
              const SizedBox(height: 6),
              Text(
                'Set your username and password. You will use these to sign in.',
                style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 28),

              // Username
              AppTextField(
                controller: _username,
                label: 'Username',
                keyboard: TextInputType.text,
                hint: 'e.g. alex_johnson',
                errorText: _usernameError,
                onChanged: _onUsernameChanged,
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: usernameStatus,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Lowercase letters, numbers, underscores. 3-30 characters.',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // Password
              AppTextField(
                controller: _password,
                label: 'Password',
                obscure: _obscurePassword,
                hint: 'Min. 8 chars with letter and number',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20, color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 12),

              // Confirm Password
              AppTextField(
                controller: _confirmPassword,
                label: 'Confirm Password',
                obscure: _obscureConfirm,
                hint: 'Re-enter your password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20, color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(message: _error!),
              ],

              const SizedBox(height: 28),

              AppButton(
                text: _loading ? 'Creating Account...' : 'Complete Registration',
                onPressed: _loading ? null : _completeRegistration,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
