// lib/features/profile/presentation/member_profile_screen.dart
// Athlete Profile & Account Management — LiftFlow (Apex Precision)
// Sections: Personal Details (editable) · Notifications (live DB) ·
//           Account & Security (change password) · Records & History · Sign Out
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../attendance_history/presentation/attendance_history_screen.dart';
import '../../auth/auth_notifier.dart';
import '../profile_notifier.dart';

// ── Provider: resolve member row ID from profiles.user_id ─────────────────

final _memberIdProvider = FutureProvider.family<String?, String>(
    (ref, userId) async {
  final rows = await AppSupabase.client
      .from('members')
      .select('id')
      .eq('profile_id', userId)
      .limit(1);
  final list = rows as List;
  if (list.isEmpty) return null;
  return list[0]['id'] as String?;
});

// ══════════════════════════════════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════════════════════════════════

class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName =
        (profile.fullName?.isNotEmpty == true ? profile.fullName! : profile.username ?? 'Athlete');
    final initial = displayName[0].toUpperCase();

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
            // ── 1. Athlete Header Card (tappable to edit) ──────────────────
            _ProfileHeaderCard(
              initial: initial,
              displayName: displayName,
              username: profile.username,
              phone: profile.phone,
              role: profile.role.name.toUpperCase(),
              isDark: isDark,
              cs: cs,
              onEditTap: () => _showEditDetailsSheet(context, ref, profile.userId),
            ),
            const SizedBox(height: 24),

            // ── 2. Records & History ────────────────────────────────────────
            _SectionLabel('RECORDS & HISTORY', cs: cs),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.calendar_today_rounded,
              title: 'Check-in Attendance Log',
              subtitle: 'View past visits and streak timeline',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
              ),
            ),
            const SizedBox(height: 24),

            // ── 3. Notifications (live DB) ──────────────────────────────────
            _SectionLabel('NOTIFICATIONS & ALERTS', cs: cs),
            const SizedBox(height: 10),
            _NotificationPrefsSection(userId: profile.userId),
            const SizedBox(height: 24),

            // ── 4. Account & Security ───────────────────────────────────────
            _SectionLabel('ACCOUNT & SECURITY', cs: cs),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: () => _showChangePasswordSheet(context, ref),
            ),
            const SizedBox(height: 32),

            // ── 5. Sign Out ─────────────────────────────────────────────────
            AppButton(
              text: 'Sign Out of LiftFlow',
              icon: const Icon(Icons.logout_rounded),
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text(
                        'Are you sure you want to sign out of your account?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authActionsProvider).signOut();
                }
              },
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Bottom-sheet: Edit Personal Details ──────────────────────────────────

  void _showEditDetailsSheet(
      BuildContext context, WidgetRef ref, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditDetailsSheet(userId: userId, ref: ref),
    );
  }

  // ── Bottom-sheet: Change Password ─────────────────────────────────────────

  void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(ref: ref),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Profile Header Card
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileHeaderCard extends StatelessWidget {
  final String initial;
  final String displayName;
  final String? username;
  final String? phone;
  final String role;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onEditTap;

  const _ProfileHeaderCard({
    required this.initial,
    required this.displayName,
    required this.username,
    required this.phone,
    required this.role,
    required this.isDark,
    required this.cs,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEditTap,
      borderRadius: AppRadii.card,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.dSurface : AppColors.lSurface,
          borderRadius: AppRadii.card,
          border: Border.all(
            color: isDark ? AppColors.brand.withAlpha(50) : cs.outline,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.brand.withAlpha(30)
                    : AppColors.brandContainer,
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
                    displayName,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${username ?? 'user'} • $role',
                    style: AppTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (phone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone!,
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            // Edit hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.brand.withAlpha(20)
                    : AppColors.brandContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined,
                      size: 12,
                      color: isDark ? AppColors.brand : AppColors.brandDark),
                  const SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.brand : AppColors.brandDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Notification Preferences Section
// ══════════════════════════════════════════════════════════════════════════════

class _NotificationPrefsSection extends ConsumerWidget {
  final String userId;
  const _NotificationPrefsSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberIdAsync = ref.watch(_memberIdProvider(userId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return memberIdAsync.when(
      data: (memberId) {
        if (memberId == null) {
          // Member row not found — show local-only toggles with explanation
          return _LocalOnlyToggles(isDark: isDark, cs: cs);
        }
        return _LiveNotifToggles(
            memberId: memberId, isDark: isDark, cs: cs, ref: ref);
      },
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, e) => _LocalOnlyToggles(isDark: isDark, cs: cs),
    );
  }
}

// Live-persisted toggles (member row found)
class _LiveNotifToggles extends ConsumerWidget {
  final String memberId;
  final bool isDark;
  final ColorScheme cs;
  // ignore: unused_field — ref forwarded to build
  final WidgetRef ref;

  const _LiveNotifToggles({
    required this.memberId,
    required this.isDark,
    required this.cs,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider(memberId));

    return prefsAsync.when(
      data: (prefs) => _ToggleContainer(
        isDark: isDark,
        cs: cs,
        items: [
          _ToggleItem(
            title: 'Push Notifications',
            subtitle: 'Workout reminders & streak alerts',
            icon: Icons.notifications_outlined,
            value: prefs.pushEnabled,
            onChanged: (val) async {
              // Optimistic invalidation after save
              await ref
                  .read(profileActionsProvider)
                  .setNotificationPref(
                      memberId: memberId, channel: 'push', optedIn: val);
              ref.invalidate(notificationPrefsProvider(memberId));
            },
          ),
          _ToggleItem(
            title: 'Email Alerts',
            subtitle: 'Membership expiry & renewal reminders',
            icon: Icons.email_outlined,
            value: prefs.emailEnabled,
            onChanged: (val) async {
              await ref
                  .read(profileActionsProvider)
                  .setNotificationPref(
                      memberId: memberId, channel: 'email', optedIn: val);
              ref.invalidate(notificationPrefsProvider(memberId));
            },
          ),
        ],
      ),
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, e) => _LocalOnlyToggles(isDark: isDark, cs: cs),
    );
  }
}

// Fallback when member row not available (edge case)
class _LocalOnlyToggles extends StatefulWidget {
  final bool isDark;
  final ColorScheme cs;
  const _LocalOnlyToggles({required this.isDark, required this.cs});

  @override
  State<_LocalOnlyToggles> createState() => _LocalOnlyTogglesState();
}

class _LocalOnlyTogglesState extends State<_LocalOnlyToggles> {
  bool _push = true;
  bool _email = true;

  @override
  Widget build(BuildContext context) {
    return _ToggleContainer(
      isDark: widget.isDark,
      cs: widget.cs,
      items: [
        _ToggleItem(
          title: 'Push Notifications',
          subtitle: 'Workout reminders & streak alerts',
          icon: Icons.notifications_outlined,
          value: _push,
          onChanged: (v) => setState(() => _push = v),
        ),
        _ToggleItem(
          title: 'Email Alerts',
          subtitle: 'Membership expiry & renewal reminders',
          icon: Icons.email_outlined,
          value: _email,
          onChanged: (v) => setState(() => _email = v),
        ),
      ],
    );
  }
}

// Shared container wrapping the toggle tiles
class _ToggleContainer extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final List<_ToggleItem> items;

  const _ToggleContainer(
      {required this.isDark, required this.cs, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurface : AppColors.lSurface,
        borderRadius: AppRadii.card,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            items[i],
          ]
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Icon(icon,
          size: 20,
          color: value
              ? (isDark ? AppColors.brand : AppColors.brandDark)
              : Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall
            .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      value: value,
      activeThumbColor: isDark ? AppColors.brand : AppColors.brandDark,
      onChanged: onChanged,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Edit Personal Details Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _EditDetailsSheet extends ConsumerStatefulWidget {
  final String userId;
  final WidgetRef ref;

  const _EditDetailsSheet({required this.userId, required this.ref});

  @override
  ConsumerState<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends ConsumerState<_EditDetailsSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authStateProvider).valueOrNull;
    _nameCtrl =
        TextEditingController(text: profile?.fullName ?? '');
    _phoneCtrl =
        TextEditingController(text: profile?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actions = ref.read(profileActionsProvider);
      final newName = _nameCtrl.text.trim();
      final newPhone = _phoneCtrl.text.trim();

      // Only call if changed
      final profile = ref.read(authStateProvider).valueOrNull;
      if (newName != (profile?.fullName ?? '')) {
        await actions.updateFullName(widget.userId, newName);
      }
      if (newPhone.isNotEmpty && newPhone != (profile?.phone ?? '')) {
        await actions.updatePhone(widget.userId, newPhone);
      }

      // Refresh the auth profile stream so the header re-renders
      ref.invalidate(authStateProvider);

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _BottomSheetShell(
      title: 'Edit Personal Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full Name
          _SheetTextField(
            controller: _nameCtrl,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            keyboard: TextInputType.name,
            isDark: isDark,
            cs: cs,
          ),
          const SizedBox(height: 14),

          // Phone
          _SheetTextField(
            controller: _phoneCtrl,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            isDark: isDark,
            cs: cs,
          ),
          const SizedBox(height: 14),

          // Username — read-only
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.dSurfaceAlt
                  : AppColors.lSurfaceAlt,
              borderRadius: AppRadii.r8,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.alternate_email_rounded,
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Username',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '@${profile?.username ?? '—'}',
                        style: AppTypography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.outline.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Locked',
                      style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],

          const SizedBox(height: 20),
          AppButton(
            text: 'Save Changes',
            loading: _saving,
            fullWidth: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Change Password Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _ChangePasswordSheet({required this.ref});

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPass = _newPasswordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(profileActionsProvider).changePassword(newPass);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password updated successfully'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _BottomSheetShell(
      title: 'Change Password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTextField(
            controller: _newPasswordCtrl,
            label: 'New Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureNew,
            isDark: isDark,
            cs: cs,
            suffixIcon: IconButton(
              icon: Icon(_obscureNew
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              iconSize: 18,
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          const SizedBox(height: 14),
          _SheetTextField(
            controller: _confirmCtrl,
            label: 'Confirm New Password',
            icon: Icons.lock_reset_rounded,
            obscure: _obscureConfirm,
            isDark: isDark,
            cs: cs,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              iconSize: 18,
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 8),
          Text(
            'Minimum 8 characters. You will remain signed in after the change.',
            style: AppTypography.bodySmall
                .copyWith(color: cs.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 20),
          AppButton(
            text: 'Update Password',
            loading: _saving,
            fullWidth: true,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

/// Pill-shaped bottom sheet shell with drag handle + title.
class _BottomSheetShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.dSurface : AppColors.lSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

/// Styled text field for use inside bottom sheets.
class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? suffixIcon;
  final bool isDark;
  final ColorScheme cs;

  const _SheetTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    required this.cs,
    this.obscure = false,
    this.keyboard,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: AppRadii.r8,
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.r8,
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.r8,
          borderSide: BorderSide(
              color: isDark ? AppColors.brand : AppColors.brandDark,
              width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

/// Inline error banner shown in bottom sheets.
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: AppRadii.r8,
        border:
            Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section label above grouped tiles.
class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;

  const _SectionLabel(this.text, {required this.cs});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelAthletic.copyWith(
        fontSize: 11,
        letterSpacing: 1.5,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

/// Standard menu navigation tile (unchanged from original design).
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
              child: Icon(icon,
                  color: isDark ? AppColors.brand : AppColors.brandDark,
                  size: 20),
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
