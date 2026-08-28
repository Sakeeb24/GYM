// lib/core/widgets/main_scaffold.dart
import 'package:flutter/material.dart';
import '../business_rules/business_rules.dart';
import '../../features/dashboard/presentation/owner_dashboard_screen.dart';
import '../../features/members/presentation/members_screen.dart';
import '../../features/red_list/presentation/red_list_screen.dart';
import '../../features/qr_checkin/presentation/qr_checkin_screen.dart';
import '../../features/renewals/presentation/renewals_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

class MainScaffold extends StatefulWidget {
  final AppRole role;
  const MainScaffold({super.key, required this.role});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = _rolePages(widget.role, _index);
    final destinations = _roleDestinations(widget.role);
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }

  List<NavigationDestination> _roleDestinations(AppRole role) {
    switch (role) {
      case AppRole.owner:
        return const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), label: 'Red List'),
          NavigationDestination(icon: Icon(Icons.currency_exchange), label: 'Renewals'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payments'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ];
      case AppRole.frontDesk:
        return const [
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Check-in'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), label: 'Red List'),
        ];
      case AppRole.member:
        return const [
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.currency_exchange), label: 'Renewals'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payments'),
        ];
      case AppRole.trainer:
        return const [
          NavigationDestination(icon: Icon(Icons.coerce), label: 'Coaching'),
        ];
    }
  }

  List<Widget> _rolePages(AppRole role, int selected) {
    final all = switch (role) {
      AppRole.owner => const <Widget>[
        OwnerDashboardScreen(),
        MembersScreen(),
        RedListScreen(),
        RenewalsScreen(),
        PaymentsScreen(),
        SettingsScreen(),
      ],
      AppRole.frontDesk => const <Widget>[QrCheckInScreen(), RedListScreen()],
      AppRole.member => const <Widget>[QrCheckInScreen(), RenewalsScreen(), PaymentsScreen()],
      AppRole.trainer => const <Widget>[Center(child: Text('Coaching area - coming soon'))],
    };
    // IndexedStack keeps all children alive; only the selected shows.
    return all;
  }
}
