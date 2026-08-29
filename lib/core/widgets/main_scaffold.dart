// lib/core/widgets/main_scaffold.dart
// Athletic Multi-Role Navigation Shell with Athletic Header & Quick Profile Access
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../business_rules/business_rules.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/dashboard/presentation/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/member_dashboard_screen.dart';
import '../../features/members/presentation/members_screen.dart';
import '../../features/red_list/presentation/red_list_screen.dart';
import '../../features/qr_checkin/presentation/qr_checkin_screen.dart';
import '../../features/renewals/presentation/renewals_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final AppRole role;
  const MainScaffold({super.key, required this.role});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;

  void _showProfileSheet(BuildContext context) {
    final profile = ref.read(authStateProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.brand, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        (profile?.fullName?.isNotEmpty == true
                                ? profile!.fullName![0]
                                : profile?.username?[0] ?? 'A')
                            .toUpperCase(),
                        style: AppTypography.headlineLarge.copyWith(
                          color: isDark ? AppColors.brand : AppColors.brandDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.fullName ?? profile?.username ?? 'Athlete',
                          style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profile?.username ?? 'user'} • ${profile?.role.name.toUpperCase() ?? 'MEMBER'}',
                          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (profile?.phone != null)
                          Text(
                            profile!.phone!,
                            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                ),
                title: Text(
                  'Sign Out of LiftFlow',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(authActionsProvider).signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _rolePages(widget.role);
    final destinations = _roleDestinations(widget.role);
    final safeIndex = _index < pages.length ? _index : 0;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.brand),
            ),
            const SizedBox(width: 10),
            Text(
              'LIFTFLOW',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 16,
                letterSpacing: 2.0,
                color: isDark ? AppColors.brand : AppColors.brandDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cs.outline),
            ),
            child: Text(
              widget.role.name.toUpperCase(),
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 10,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Profile & Account',
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: isDark ? AppColors.brand.withAlpha(40) : AppColors.brandContainer,
              child: Text(
                (profile?.fullName?.isNotEmpty == true
                        ? profile!.fullName![0]
                        : profile?.username?[0] ?? 'A')
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.brand : AppColors.brandDark,
                ),
              ),
            ),
            onPressed: () => _showProfileSheet(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outline, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: destinations,
          height: 64,
        ),
      ),
    );
  }

  List<NavigationDestination> _roleDestinations(AppRole role) {
    switch (role) {
      case AppRole.owner:
        return const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Red List',
          ),
          NavigationDestination(
            icon: Icon(Icons.autorenew_outlined),
            selectedIcon: Icon(Icons.autorenew_rounded),
            label: 'Renewals',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ];
      case AppRole.frontDesk:
        return const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Check-in',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Red List',
          ),
        ];
      case AppRole.trainer:
        return const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Check-in',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded),
            label: 'Members',
          ),
        ];
      case AppRole.member:
        return const [
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge_rounded),
            label: 'Pass',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.autorenew_outlined),
            selectedIcon: Icon(Icons.autorenew_rounded),
            label: 'Renewals',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Payments',
          ),
        ];
    }
  }

  List<Widget> _rolePages(AppRole role) {
    return switch (role) {
      AppRole.owner => const <Widget>[
        OwnerDashboardScreen(),
        MembersScreen(),
        RedListScreen(),
        RenewalsScreen(),
        PaymentsScreen(),
        SettingsScreen(),
      ],
      AppRole.frontDesk => const <Widget>[
        QrCheckInScreen(),
        MembersScreen(),
        RedListScreen(),
      ],
      AppRole.trainer => const <Widget>[
        QrCheckInScreen(),
        MembersScreen(),
      ],
      AppRole.member => const <Widget>[
        MemberDashboardScreen(),
        QrCheckInScreen(),
        RenewalsScreen(),
        PaymentsScreen(),
      ],
    };
  }
}
