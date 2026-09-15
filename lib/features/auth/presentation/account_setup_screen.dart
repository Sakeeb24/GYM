import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../auth_notifier.dart';
import 'auth_widgets.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  final String fullName;
  final String phone;
  final String activationToken;
  final String? gymName;

  const AccountSetupScreen({
    super.key,
    required this.fullName,
    required this.phone,
    required this.activationToken,
    this.gymName,
  });

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscure = true;
  String? _localError;
  bool _submitting = false;
  bool _created = false;
  bool _isTokenError = false;

  @override
  void initState() {
    super.initState();
    _username.addListener(_onFieldChanged);
    _password.addListener(_onFieldChanged);
    _confirmPassword.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_localError != null) {
      setState(() {
        _localError = null;
        _isTokenError = false;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _username.removeListener(_onFieldChanged);
    _password.removeListener(_onFieldChanged);
    _confirmPassword.removeListener(_onFieldChanged);
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    final u = _username.text.trim().toLowerCase();
    final p = _password.text; // Preserve exact untrimmed password
    final cp = _confirmPassword.text;

    if (u.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _localError = 'Please choose a username.');
      return;
    }
    if (u.length < 3) {
      HapticFeedback.mediumImpact();
      setState(() => _localError = 'Username must be at least 3 characters.');
      return;
    }
    if (p.length < 8) {
      HapticFeedback.mediumImpact();
      setState(() => _localError = 'Password must be at least 8 characters.');
      return;
    }
    if (p != cp) {
      HapticFeedback.mediumImpact();
      setState(() => _localError = 'Passwords do not match. Please re-enter.');
      return;
    }

    setState(() {
      _submitting = true;
      _isTokenError = false;
    });

    try {
      await ref.read(authActionsProvider).registerMember(
            fullName: widget.fullName,
            phone: widget.phone,
            activationToken: widget.activationToken,
            username: u,
            password: p,
          );

      HapticFeedback.heavyImpact();
      setState(() => _created = true);

      // Brief celebration pause before directing to login
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        final rawMsg = e.toString().toLowerCase();
        final mapped = AppErrorMapper.toUserMessage(e);
        final isToken = rawMsg.contains('token') ||
            rawMsg.contains('activation') ||
            rawMsg.contains('expired') ||
            rawMsg.contains('invalid qr');

        HapticFeedback.mediumImpact();
        setState(() {
          _localError = mapped;
          _isTokenError = isToken;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final u = _username.text.trim();
    final p = _password.text;
    final cp = _confirmPassword.text;

    final hasMinLength = p.length >= 8;
    final passwordsMatch = p.isNotEmpty && p == cp;
    final hasValidUsername = u.length >= 3;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
        ),
        title: Text(
          'CREATE CREDENTIALS',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthStepIndicator(current: 3, total: 3),
                  const SizedBox(height: 16),

                  if (_created) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brand.withAlpha(120),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, size: 40, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Account Created!',
                        style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (widget.gymName != null && widget.gymName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.brand.withAlpha(60)),
                          ),
                          child: Text(
                            'WELCOME TO ${widget.gymName!.toUpperCase()}',
                            style: AppTypography.labelAthletic.copyWith(
                              fontSize: 11,
                              letterSpacing: 1.0,
                              color: isDark ? AppColors.brand : AppColors.brandDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Redirecting you to sign in with your new credentials...',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else if (widget.activationToken.isEmpty || widget.phone.isEmpty) ...[
                    // Safeguard if user directly navigates to Step 3 without completing Step 2
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.warning.withAlpha(120), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 40, color: AppColors.warning),
                          const SizedBox(height: 12),
                          Text(
                            'VERIFICATION REQUIRED',
                            style: AppTypography.labelAthletic.copyWith(
                              color: AppColors.warning,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please complete Step 2 (Gym Verification) before creating your credentials.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            text: 'Go to Step 2 (Verify Gym)',
                            onPressed: () => context.go('/verify-gym', extra: {
                              'fullName': widget.fullName,
                              'phone': widget.phone,
                            }),
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Choose Your Login',
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.gymName != null && widget.gymName!.isNotEmpty
                          ? 'Step 3 of 3: Set up your username and password for ${widget.gymName}.'
                          : 'Step 3 of 3: Set up your username and password to access your gym.',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),

                    // Username
                    AppTextField(
                      label: 'Username',
                      controller: _username,
                      hint: 'e.g. alex_lift',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),

                    // Password
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      obscure: _obscure,
                      hint: 'Minimum 8 characters',
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Confirm Password
                    AppTextField(
                      label: 'Confirm Password',
                      controller: _confirmPassword,
                      obscure: _obscure,
                      hint: 'Re-enter your password',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 10),

                    // Compact athletic credential requirement badges
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _RequirementPill(
                            label: '3+ USER',
                            isMet: hasValidUsername,
                          ),
                          _RequirementPill(
                            label: '8+ PASS',
                            isMet: hasMinLength,
                          ),
                          _RequirementPill(
                            label: 'MATCH',
                            isMet: passwordsMatch,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_localError != null) ...[
                      AuthErrorBanner(
                        message: _localError!,
                        onRetry: _isTokenError
                            ? () => context.go('/verify-gym', extra: {
                                  'fullName': widget.fullName,
                                  'phone': widget.phone,
                                })
                            : null,
                        retryLabel: _isTokenError ? 'Re-scan Gym QR' : null,
                      ),
                      const SizedBox(height: 10),
                    ],

                    AppButton(
                      text: _submitting ? 'Creating account...' : 'Complete Registration',
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

class _RequirementPill extends StatelessWidget {
  final String label;
  final bool isMet;

  const _RequirementPill({required this.label, required this.isMet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMet
            ? AppColors.success.withAlpha(25)
            : (isDark ? AppColors.dSurfaceElevated : cs.surfaceContainerHighest.withAlpha(80)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMet ? AppColors.success.withAlpha(120) : cs.outlineVariant.withAlpha(80),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 12,
            color: isMet ? AppColors.success : cs.onSurfaceVariant.withAlpha(140),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelAthletic.copyWith(
              fontSize: 10,
              letterSpacing: 0.5,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
              color: isMet ? AppColors.success : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
