// lib/features/settings/presentation/settings_screen.dart
// Clean Gym Settings (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/business_rules/business_rules.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
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
          const SnackBar(content: Text('Settings saved successfully!')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: AppRadii.r12,
                    border: Border.all(color: cs.outline),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.brand.withAlpha(25),
                        child: Text(
                          (profile.fullName?.isNotEmpty == true
                                  ? profile.fullName![0]
                                  : profile.username?[0] ?? 'A')
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName ?? profile.username ?? 'Staff',
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            Text(
                              '@${profile.username ?? 'user'} • ${profile.role.name.toUpperCase()}',
                              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 2. GYM SETTINGS ─────────────────────────────────────
                if (isOwner) ...[
                  Text(
                    'Gym Operations',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: AppRadii.r12,
                      border: Border.all(color: cs.outline),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _inactivity,
                          label: 'No-Show Inactivity Threshold (Days)',
                          keyboard: TextInputType.number,
                          hint: 'Default: 7 days',
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _graceMinutes,
                          label: 'QR Check-in Dedup Grace (Minutes)',
                          keyboard: TextInputType.number,
                          hint: 'Default: 5 minutes',
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          text: _saving ? 'Saving...' : 'Save Parameters',
                          onPressed: _saving ? null : () => _save(profile.gymId),
                          fullWidth: true,
                          height: 42,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.save_rounded, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 3. NOTIFICATIONS ────────────────────────────────────
                Text(
                  'Notifications & Alerts',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Material(
                  color: cs.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.r12,
                    side: BorderSide(color: cs.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _whatsappAlerts,
                        onChanged: (v) => setState(() => _whatsappAlerts = v),
                        title: Text('WhatsApp Expiry Reminders', style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Send automatic renewal alerts to at-risk members', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                        activeThumbColor: AppColors.brand,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _emailAlerts,
                        onChanged: (v) => setState(() => _emailAlerts = v),
                        title: Text('Daily Performance Digest', style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Email summary of daily check-ins and revenue', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                        activeThumbColor: AppColors.brand,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 4. ACCOUNT & SIGN OUT ───────────────────────────────
                AppButton(
                  text: 'Sign Out of LiftFlow',
                  variant: AppButtonVariant.danger,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  fullWidth: true,
                  height: 44,
                  onPressed: () => ref.read(authActionsProvider).signOut(),
                ),
                const SizedBox(height: 16),

                Center(
                  child: Text(
                    'LiftFlow Fitness SaaS v1.0.0+1',
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
