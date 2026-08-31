// lib/features/auth/presentation/owner_register_screen.dart
// Owner Registration: Gym Setup + Owner Account (single scrollable form)
//
// SECURITY: The setup_secret is only sent to the Edge Function server-side.
// Role assignment (role='owner') is performed exclusively on the server —
// this screen never constructs or sends a 'role' field.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../owner_registration_repository.dart';
import 'auth_widgets.dart';

class OwnerRegisterScreen extends ConsumerStatefulWidget {
  const OwnerRegisterScreen({super.key});

  @override
  ConsumerState<OwnerRegisterScreen> createState() => _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends ConsumerState<OwnerRegisterScreen> {
  // ── Gym Details ────────────────────────────────────────────────────────────
  final _gymName   = TextEditingController();
  final _gymSlug   = TextEditingController();

  // ── Owner Account ──────────────────────────────────────────────────────────
  final _fullName  = TextEditingController();
  final _phone     = TextEditingController();
  final _username  = TextEditingController();
  final _password  = TextEditingController();
  final _confirm   = TextEditingController();
  final _setupCode = TextEditingController();

  bool   _obscurePassword = true;
  bool   _obscureCode     = true;
  bool   _submitting      = false;
  bool   _success         = false;
  String? _error;

  // Track whether the slug has been manually edited by the user.
  bool _slugManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _gymName.addListener(_onGymNameChanged);
  }

  @override
  void dispose() {
    _gymName.removeListener(_onGymNameChanged);
    _gymName.dispose();
    _gymSlug.dispose();
    _fullName.dispose();
    _phone.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    _setupCode.dispose();
    super.dispose();
  }

  void _onGymNameChanged() {
    if (_slugManuallyEdited) return;
    final derived = _slugify(_gymName.text);
    if (_gymSlug.text != derived) {
      _gymSlug.text = derived;
    }
  }

  static String _slugify(String name) {
    final cleaned = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    final gymName   = _gymName.text.trim();
    final gymSlug   = _gymSlug.text.trim().toLowerCase();
    final fullName  = _fullName.text.trim();
    final phone     = _phone.text.trim();
    final username  = _username.text.trim().toLowerCase();
    final password  = _password.text; // never trim passwords
    final confirm   = _confirm.text;
    final setupCode = _setupCode.text.trim();

    // ── Client-side validation ─────────────────────────────────────────────
    if (gymName.length < 2) {
      setState(() => _error = 'Gym name must be at least 2 characters.');
      return;
    }
    if (gymSlug.length < 2 || !RegExp(r'^[a-z0-9][a-z0-9\-]*[a-z0-9]$|^[a-z0-9]{2,}$').hasMatch(gymSlug)) {
      setState(() => _error = 'Gym slug must be 2+ characters: lowercase letters, digits, and hyphens only.');
      return;
    }
    if (fullName.length < 2) {
      setState(() => _error = 'Please enter your full name (at least 2 characters).');
      return;
    }
    if (phone.isEmpty || phone.length < 8) {
      setState(() => _error = 'Please enter a valid phone number.');
      return;
    }
    if (username.isEmpty || username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters.');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(username)) {
      setState(() => _error = 'Username may only contain lowercase letters, digits, and underscores.');
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
    if (setupCode.isEmpty) {
      setState(() => _error = 'Please enter the setup code provided by LiftFlow.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(ownerRegistrationRepositoryProvider).registerOwner(
        gymName:     gymName,
        gymSlug:     gymSlug,
        fullName:    fullName,
        phone:       phone,
        username:    username,
        password:    password,
        setupSecret: setupCode,
      );

      if (mounted) setState(() => _success = true);

      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppErrorMapper.toUserMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'GYM SETUP',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _success ? _buildSuccess(cs) : _buildForm(cs, isDark),
            ),
          ),
        ),
      ),
    );
  }

  // ── Success state ───────────────────────────────────────────────────────────
  Widget _buildSuccess(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),
        const CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.brand,
          child: Icon(Icons.storefront_rounded, size: 44, color: Colors.black),
        ),
        const SizedBox(height: 24),
        Text(
          'Gym Created!',
          style: AppTypography.headlineLarge.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your LiftFlow gym and owner account have been set up.\nRedirecting to sign in…',
          style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Main form ───────────────────────────────────────────────────────────────
  Widget _buildForm(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.storefront_rounded,
              size: 28,
              color: isDark ? AppColors.brand : AppColors.brandDark,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Set Up Your Gym',
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Create your LiftFlow gym and owner account.',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),

        // ── Section A: Gym Details ───────────────────────────────────────────
        _SectionHeader(
          label: '01 GYM DETAILS',
          icon: Icons.fitness_center_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 14),

        AppTextField(
          controller: _gymName,
          label: 'Gym Name',
          hint: 'e.g. Iron Forge Fitness',
          keyboard: TextInputType.text,
        ),
        const SizedBox(height: 14),

        // Slug field with live preview
        AppTextField(
          controller: _gymSlug,
          label: 'Gym Slug (URL handle)',
          hint: 'e.g. iron-forge',
          keyboard: TextInputType.url,
          onChanged: (_) {
            if (!_slugManuallyEdited && _gymSlug.text != _slugify(_gymName.text)) {
              setState(() => _slugManuallyEdited = true);
            }
          },
        ),
        const SizedBox(height: 4),
        // Slug preview label
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _gymSlug,
          builder: (_, v, _) {
            final slug = v.text.trim();
            if (slug.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Handle: $slug',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // ── Section B: Owner Account ─────────────────────────────────────────
        _SectionHeader(
          label: '02 YOUR ACCOUNT',
          icon: Icons.person_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 14),

        AppTextField(
          controller: _fullName,
          label: 'Full Name',
          hint: 'e.g. Sarah Patel',
          keyboard: TextInputType.name,
        ),
        const SizedBox(height: 14),

        AppTextField(
          controller: _phone,
          label: 'Phone Number',
          hint: '+91 98765 43210',
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: 14),

        AppTextField(
          controller: _username,
          label: 'Username',
          hint: 'e.g. sarah_gym',
        ),
        const SizedBox(height: 14),

        AppTextField(
          controller: _password,
          label: 'Password',
          hint: 'Minimum 8 characters',
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 14),

        AppTextField(
          controller: _confirm,
          label: 'Confirm Password',
          hint: 'Re-enter your password',
          obscure: _obscurePassword,
        ),
        const SizedBox(height: 24),

        // ── Section C: Setup Authorisation ───────────────────────────────────
        _SectionHeader(
          label: '03 AUTHORISATION',
          icon: Icons.lock_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the setup code provided by LiftFlow to authorise this gym registration.',
          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),

        AppTextField(
          controller: _setupCode,
          label: 'Setup Code',
          hint: 'Provided by LiftFlow support',
          obscure: _obscureCode,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureCode ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _obscureCode = !_obscureCode),
          ),
        ),
        const SizedBox(height: 24),

        // ── Error Banner ──────────────────────────────────────────────────────
        if (_error != null) ...[
          AuthErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],

        // ── Submit ────────────────────────────────────────────────────────────
        AppButton(
          text: _submitting ? 'Setting up gym…' : 'Create Gym & Account',
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
        const SizedBox(height: 16),

        Center(
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  'Sign In',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.brand : AppColors.brandDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Small section header with icon and athletic label.
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer,
            borderRadius: AppRadii.r8,
          ),
          child: Icon(icon, size: 13, color: isDark ? AppColors.brand : AppColors.brandDark),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 11,
            letterSpacing: 1.2,
            color: isDark ? AppColors.brand : AppColors.brandDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: isDark ? AppColors.dBorder : AppColors.lBorder),
        ),
      ],
    );
  }
}
