// lib/features/auth/presentation/register_screen.dart
// Athletic Registration Step 1 — Personal Info
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../auth_notifier.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7 && digits.length <= 15;
  }

  Future<void> _sendOtp() async {
    final fullName = _fullName.text.trim();
    final phone = _phone.text.trim();

    if (fullName.length < 2) {
      setState(() => _error = 'Please enter your full name (at least 2 characters).');
      return;
    }
    if (!_isValidPhone(phone)) {
      setState(() => _error = 'Please enter a valid phone number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final actions = ref.read(authActionsProvider);
      await actions.sendPhoneOtp(phone);
      if (mounted) {
        context.push('/otp', extra: {'full_name': fullName, 'phone': phone});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to send OTP: ${e.toString().replaceAll('Exception:', '').trim()}');
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'NEW ATHLETE ONBOARDING',
          style: AppTypography.labelAthletic.copyWith(
            color: isDark ? AppColors.brand : AppColors.brandDark,
            fontSize: 12,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthStepIndicator(current: 1, total: 3),
                const SizedBox(height: 28),

                // Athletic Header
                Text(
                  'START YOUR JOURNEY',
                  style: AppTypography.displayMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Build your profile. Build your strength. Enter the details registered with your gym.',
                  style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 28),

                // Input Card
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline, width: 1),
                    boxShadow: isDark ? AppShadows.cardElevation : AppShadows.md,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _fullName,
                        label: 'Full Name',
                        keyboard: TextInputType.name,
                        hint: 'e.g. Alex Johnson',
                        suffixIcon: Icon(Icons.badge_outlined, size: 20, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        controller: _phone,
                        label: 'Phone Number',
                        keyboard: TextInputType.phone,
                        hint: '+91 98765 43210',
                        suffixIcon: Icon(Icons.phone_iphone_rounded, size: 20, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We will look up your active gym membership by this phone number.',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBanner(message: _error!),
                ],

                const SizedBox(height: 28),

                AppButton(
                  text: 'Continue',
                  onPressed: _loading ? null : _sendOtp,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
