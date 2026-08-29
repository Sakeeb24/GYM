// lib/features/settings/presentation/settings_screen.dart
// Gym Operational Parameters & Account Settings
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
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
              'GYM SETTINGS',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Profile Account Card ──────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline),
                    boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOGGED IN ACCOUNT',
                        style: AppTypography.labelAthletic.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                            child: Text(
                              (profile.fullName?.isNotEmpty == true
                                      ? profile.fullName![0]
                                      : profile.username?[0] ?? 'A')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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
                                  style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '@${profile.username ?? 'user'} • ${profile.role.name.toUpperCase()}',
                                  style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ref.read(authActionsProvider).signOut(),
                        icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                        label: Text(
                          'SIGN OUT',
                          style: AppTypography.labelAthletic.copyWith(color: AppColors.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 2. Operational Thresholds (Owner Only) ───────────────
                if (isOwner) ...[
                  Text(
                    'RETENTION & QR PARAMETERS',
                    style: AppTypography.labelAthletic.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outline),
                      boxShadow: isDark ? AppShadows.cardElevation : AppShadows.sm,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _inactivity,
                          label: 'No-Show Inactivity Threshold (Days)',
                          keyboard: TextInputType.number,
                          hint: 'Default: 7 days',
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _graceMinutes,
                          label: 'QR Check-in Dedup Grace (Minutes)',
                          keyboard: TextInputType.number,
                          hint: 'Default: 5 minutes',
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          text: _saving ? 'SAVING...' : 'SAVE CONFIGURATION',
                          onPressed: _saving ? null : () => _save(profile.gymId),
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
                  const SizedBox(height: 24),
                ],

                // ── 3. App Version & Info ────────────────────────────────
                Center(
                  child: Text(
                    'LiftFlow Athletic SaaS v1.0.0+1 • Multi-Tenant Protected',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 20),
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
