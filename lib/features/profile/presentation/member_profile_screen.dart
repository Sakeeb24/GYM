// lib/features/profile/presentation/member_profile_screen.dart
// Athlete Profile & Account Preferences (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../attendance_history/presentation/attendance_history_screen.dart';
import '../../auth/auth_notifier.dart';

class MemberProfileScreen extends ConsumerStatefulWidget {
  const MemberProfileScreen({super.key});

  @override
  ConsumerState<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends ConsumerState<MemberProfileScreen> {
  bool _workoutReminders = true;
  bool _renewalAlerts = true;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initial = (profile.fullName?.isNotEmpty == true
            ? profile.fullName![0]
            : profile.username?[0] ?? 'A')
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ATHLETE PROFILE',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Athlete Header Card ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.dSurface : AppColors.lSurface,
                borderRadius: AppRadii.card,
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.brand, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: AppTypography.headlineLarge.copyWith(
                          color: isDark ? AppColors.brand : AppColors.brandDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName ?? profile.username ?? 'Athlete',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profile.username ?? 'user'} • ${profile.role.name.toUpperCase()}',
                          style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (profile.phone != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.phone!,
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 2. Quick Navigation Tiles ────────────────────────────────────
            Text(
              'RECORDS & HISTORY',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 11,
                letterSpacing: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),

            _MenuTile(
              icon: Icons.calendar_today_rounded,
              title: 'Check-in Attendance Log',
              subtitle: 'View past visits and streak timeline',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── 3. Notification Preferences ──────────────────────────────────
            Text(
              'NOTIFICATIONS & ALERTS',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 11,
                letterSpacing: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.dSurface : AppColors.lSurface,
                borderRadius: AppRadii.card,
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Workout Reminders',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Daily reminders to keep your streak alive',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                    value: _workoutReminders,
                    activeThumbColor: AppColors.brand,
                    onChanged: (val) => setState(() => _workoutReminders = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(
                      'Membership Expiry Alerts',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Get notified 14, 7, and 3 days before expiry',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                    value: _renewalAlerts,
                    activeThumbColor: AppColors.brand,
                    onChanged: (val) => setState(() => _renewalAlerts = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── 4. Sign Out Button ───────────────────────────────────────────
            AppButton(
              text: 'Sign Out of LiftFlow',
              icon: const Icon(Icons.logout_rounded),
              variant: AppButtonVariant.secondary,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out of your account?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authActionsProvider).signOut();
                }
              },
              fullWidth: true,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'LiftFlow v1.0.0+1 • Multi-tenant Athletic SaaS',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.card,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.dSurface : AppColors.lSurface,
          borderRadius: AppRadii.card,
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isDark ? AppColors.brand : AppColors.brandDark, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}
