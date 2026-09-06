// lib/core/widgets/owner_web_scaffold.dart
// Enterprise Responsive Desktop Admin Dashboard (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/dashboard/presentation/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/owner_attendance_screen.dart';
import '../../features/members/presentation/members_screen.dart';
import '../../features/qr_checkin/presentation/owner_qr_management_screen.dart';
import '../../features/red_list/presentation/red_list_screen.dart';
import '../../features/renewals/presentation/renewals_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

enum OwnerWebTab {
  dashboard,
  members,
  attendance,
  memberships,
  plans,
  payments,
  qrManagement,
  redList,
  renewals,
  analytics,
  notifications,
  staff,
  branches,
  settings,
}

class OwnerWebScaffold extends ConsumerStatefulWidget {
  const OwnerWebScaffold({super.key});

  @override
  ConsumerState<OwnerWebScaffold> createState() => _OwnerWebScaffoldState();
}

class _OwnerWebScaffoldState extends ConsumerState<OwnerWebScaffold> {
  OwnerWebTab _currentTab = OwnerWebTab.dashboard;
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // ── 1. Desktop Sidebar Navigation ──────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarCollapsed ? 76 : 240,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dSurface : AppColors.lSurface,
              border: Border(right: BorderSide(color: cs.outline, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fitness_center_rounded, size: 20, color: AppColors.brand),
                      ),
                      if (!_sidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        Text(
                          'LIFTFLOW',
                          style: AppTypography.labelAthletic.copyWith(
                            fontSize: 18,
                            letterSpacing: 2.5,
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Navigation Items List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    children: [
                      _SidebarItem(
                        icon: Icons.insights_rounded,
                        title: 'Dashboard',
                        isSelected: _currentTab == OwnerWebTab.dashboard,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.dashboard),
                      ),
                      _SidebarItem(
                        icon: Icons.groups_rounded,
                        title: 'Members',
                        isSelected: _currentTab == OwnerWebTab.members,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.members),
                      ),
                      _SidebarItem(
                        icon: Icons.fact_check_rounded,
                        title: 'Attendance',
                        isSelected: _currentTab == OwnerWebTab.attendance,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.attendance),
                      ),
                      _SidebarItem(
                        icon: Icons.qr_code_2_rounded,
                        title: 'QR Management',
                        isSelected: _currentTab == OwnerWebTab.qrManagement,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.qrManagement),
                      ),
                      _SidebarItem(
                        icon: Icons.local_fire_department_rounded,
                        title: 'Red List',
                        isSelected: _currentTab == OwnerWebTab.redList,
                        collapsed: _sidebarCollapsed,
                        badgeText: 'HOT',
                        badgeColor: AppColors.flameStreak,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.redList),
                      ),
                      _SidebarItem(
                        icon: Icons.autorenew_rounded,
                        title: 'Renewals',
                        isSelected: _currentTab == OwnerWebTab.renewals,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.renewals),
                      ),
                      _SidebarItem(
                        icon: Icons.payments_rounded,
                        title: 'Payments',
                        isSelected: _currentTab == OwnerWebTab.payments,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.payments),
                      ),
                      _SidebarItem(
                        icon: Icons.analytics_rounded,
                        title: 'Analytics',
                        isSelected: _currentTab == OwnerWebTab.analytics,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.analytics),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      _SidebarItem(
                        icon: Icons.tune_rounded,
                        title: 'Settings',
                        isSelected: _currentTab == OwnerWebTab.settings,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _currentTab = OwnerWebTab.settings),
                      ),
                    ],
                  ),
                ),

                // Collapse Toggle
                Container(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    icon: Icon(
                      _sidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Main Desktop Content Area ───────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top App Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dSurface : AppColors.lSurface,
                    border: Border(bottom: BorderSide(color: cs.outline, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _tabTitle(_currentTab).toUpperCase(),
                        style: AppTypography.labelAthletic.copyWith(
                          fontSize: 16,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      // Gym Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cs.outline),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.business_rounded, size: 14, color: AppColors.brand),
                            const SizedBox(width: 6),
                            Text(
                              'OWNER PORTAL',
                              style: AppTypography.labelAthletic.copyWith(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // User Avatar & Name
                      if (profile != null) ...[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isDark ? AppColors.brand.withAlpha(40) : AppColors.brandContainer,
                          child: Text(
                            (profile.fullName?.isNotEmpty == true
                                    ? profile.fullName![0]
                                    : profile.username?[0] ?? 'O')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.brand : AppColors.brandDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profile.fullName ?? profile.username ?? 'Owner',
                          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Sign out
                      IconButton(
                        tooltip: 'Sign Out',
                        icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                        onPressed: () async {
                          await ref.read(authActionsProvider).signOut();
                        },
                      ),
                    ],
                  ),
                ),

                // Content View
                Expanded(
                  child: _tabContent(_currentTab),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tabTitle(OwnerWebTab tab) {
    return switch (tab) {
      OwnerWebTab.dashboard => 'Executive Dashboard',
      OwnerWebTab.members => 'Member Roster & Athlete Profiles',
      OwnerWebTab.attendance => 'Live Attendance & Check-in Stream',
      OwnerWebTab.memberships => 'Membership Statuses',
      OwnerWebTab.plans => 'Membership Plans & Pricing',
      OwnerWebTab.payments => 'Financial Invoices & Payment Ledger',
      OwnerWebTab.qrManagement => 'Dual QR Architecture Management',
      OwnerWebTab.redList => 'Red List (No-Show Retention Engine)',
      OwnerWebTab.renewals => 'Membership Renewals Pipeline',
      OwnerWebTab.analytics => 'Business Intelligence & Retention Analytics',
      OwnerWebTab.notifications => 'System & Member Notifications',
      OwnerWebTab.staff => 'Staff & Role Permissions',
      OwnerWebTab.branches => 'Branch Locations',
      OwnerWebTab.settings => 'Gym Settings & Business Configuration',
    };
  }

  Widget _tabContent(OwnerWebTab tab) {
    return switch (tab) {
      OwnerWebTab.dashboard => const OwnerDashboardScreen(),
      OwnerWebTab.members => const MembersScreen(),
      OwnerWebTab.attendance => const OwnerAttendanceScreen(),
      OwnerWebTab.memberships => const MembersScreen(),
      OwnerWebTab.plans => const SettingsScreen(),
      OwnerWebTab.payments => const PaymentsScreen(),
      OwnerWebTab.qrManagement => const OwnerQrManagementScreen(),
      OwnerWebTab.redList => const RedListScreen(),
      OwnerWebTab.renewals => const RenewalsScreen(),
      OwnerWebTab.analytics => const AnalyticsScreen(),
      OwnerWebTab.notifications => const SettingsScreen(),
      OwnerWebTab.staff => const SettingsScreen(),
      OwnerWebTab.branches => const SettingsScreen(),
      OwnerWebTab.settings => const SettingsScreen(),
    };
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool collapsed;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.collapsed,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer.withAlpha(50))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppColors.brand.withAlpha(120), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? (isDark ? AppColors.brand : AppColors.brandDark)
                  : cs.onSurfaceVariant,
            ),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppColors.brand).withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: badgeColor ?? AppColors.brand,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
