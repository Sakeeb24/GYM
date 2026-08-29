// lib/features/settings/presentation/settings_screen.dart
// Gym Operational Parameters & Complete Multi-Section Settings
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/auth_notifier.dart';

final gymSettingsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, gymId) async {
  final client = AppSupabase.client;
  final res = await client
      .from('gym_settings')
      .select('*')
      .eq('gym_id', gymId)
      .maybeSingle();
  return res != null ? Map<String, dynamic>.from(res as Map) : <String, dynamic>{};
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _inactivity = TextEditingController();
  final _graceMinutes = TextEditingController();
  bool _saving = false;
  bool _initialized = false;
  bool _whatsappAlerts = true;
  bool _emailAlerts = false;

  @override
  void dispose() {
    _inactivity.dispose();
    _graceMinutes.dispose();
    super.dispose();
  }

  void _initFields(Map<String, dynamic> data) {
    if (_initialized) return;
    _inactivity.text = (data['inactivity_threshold_days'] ?? 7).toString();
    _graceMinutes.text = (data['qr_session_grace_minutes'] ?? 5).toString();
    _initialized = true;
  }

  Future<void> _save(String gymId) async {
    setState(() => _saving = true);
    try {
      final inactivity = int.tryParse(_inactivity.text) ?? 7;
      final grace = int.tryParse(_graceMinutes.text) ?? 5;

      await AppSupabase.client.from('gym_settings').update({
        'inactivity_threshold_days': inactivity,
        'qr_session_grace_minutes': grace,
      }).eq('gym_id', gymId);

      ref.invalidate(gymSettingsProvider(gymId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gym operational parameters saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final isOwner = profile.role == AppRole.owner;
    final asyncSettings = ref.watch(gymSettingsProvider(profile.gymId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.tune_rounded, size: 22, color: isDark ? AppColors.brand : AppColors.brandDark),
            const SizedBox(width: 10),
            Text(
              'GYM & APP SETTINGS',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: asyncSettings.when(
        data: (settings) {
          _initFields(settings);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. PROFILE SECTION ──────────────────────────────────
                _SectionTitle(title: '01 PROFILE & ATHLETE IDENTITY'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: AppRadii.r16,
                    border: Border.all(color: cs.outline),
                    boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                        child: Text(
                          (profile.fullName?.isNotEmpty == true
                                  ? profile.fullName![0]
                                  : profile.username?[0] ?? 'A')
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName ?? profile.username ?? 'Staff',
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            Text(
                              '@${profile.username ?? 'user'} • ${profile.role.name.toUpperCase()}',
                              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                            if (profile.phone != null)
                              Text(
                                profile.phone!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark ? AppColors.brand : AppColors.brandDark,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 2. GYM SETTINGS (OPERATIONAL THRESHOLDS) ─────────────
                if (isOwner) ...[
                  _SectionTitle(title: '02 GYM OPERATIONAL SETTINGS'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: AppRadii.r16,
                      border: Border.all(color: cs.outline),
                      boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _inactivity,
                          label: 'No-Show Inactivity Threshold (Days)',
                          keyboard: TextInputType.number,
                          hint: 'Default: 7 days',
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _graceMinutes,
                          label: 'QR Check-in Dedup Grace (Minutes)',
                          keyboard: TextInputType.number,
                          hint: 'Default: 5 minutes',
                        ),
                        const SizedBox(height: 18),
                        AppButton(
                          text: _saving ? 'SAVING...' : 'SAVE PARAMETERS',
                          onPressed: _saving ? null : () => _save(profile.gymId),
                          fullWidth: true,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── 3. MEMBERSHIP SETTINGS & TIERS ───────────────────────
                _SectionTitle(title: '03 MEMBERSHIP TIERS'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: AppRadii.r16,
                    border: Border.all(color: cs.outline),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: const [
                      _TierRow(name: 'BASIC TIER', price: '₹999 / mo', features: 'Gym Access'),
                      Divider(height: 16),
                      _TierRow(name: 'PRO ATHLETE', price: '₹1,999 / mo', features: 'Access + Group Classes', isFeatured: true),
                      Divider(height: 16),
                      _TierRow(name: 'ELITE PERFORMANCE', price: '₹2,999 / mo', features: 'All Access + Personal Trainer'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 4. NOTIFICATIONS ────────────────────────────────────
                _SectionTitle(title: '04 NOTIFICATIONS & ALERTS'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: AppRadii.r16,
                    border: Border.all(color: cs.outline),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _whatsappAlerts,
                        onChanged: (v) => setState(() => _whatsappAlerts = v),
                        title: Text('WhatsApp Expiry Reminders', style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                        subtitle: Text('Send automatic renewal alerts to at-risk athletes', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                        activeThumbColor: AppColors.brand,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _emailAlerts,
                        onChanged: (v) => setState(() => _emailAlerts = v),
                        title: Text('Daily Performance Digest', style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                        subtitle: Text('Email summary of daily check-ins and revenue', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                        activeThumbColor: AppColors.brand,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 5. SECURITY & AUDIT ─────────────────────────────────
                _SectionTitle(title: '05 SECURITY & ACCESS'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: AppRadii.r16,
                    border: Border.all(color: cs.outline),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_rounded, size: 18, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(
                            'Row-Level Security Active',
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Multi-tenant database isolation enforced for ${profile.role.name.toUpperCase()}',
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 6. ACCOUNT & SIGN OUT ───────────────────────────────
                _SectionTitle(title: '06 ACCOUNT ACTIONS'),
                const SizedBox(height: 8),
                AppButton(
                  text: 'SIGN OUT OF LIFTFLOW',
                  variant: AppButtonVariant.danger,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  fullWidth: true,
                  onPressed: () => ref.read(authActionsProvider).signOut(),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'LiftFlow Fitness SaaS v1.0.0+1 • All Systems Active',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          message: 'Failed to load gym settings',
          onRetry: () => ref.refresh(gymSettingsProvider(profile.gymId).future),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.labelAthletic.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final String name;
  final String price;
  final String features;
  final bool isFeatured;

  const _TierRow({
    required this.name,
    required this.price,
    required this.features,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isFeatured ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurface,
                  ),
                ),
                if (isFeatured) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'POPULAR',
                      style: AppTypography.labelAthletic.copyWith(color: AppColors.brand, fontSize: 8),
                    ),
                  ),
                ],
              ],
            ),
            Text(features, style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
          ],
        ),
        Text(
          price,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
