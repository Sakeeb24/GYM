// lib/features/dashboard/presentation/owner_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard_repository.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../features/auth/auth_notifier.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => SupabaseDashboardRepository());

final dashboardStatsProvider = FutureProvider.family<DashboardStats, String>((ref, gymId) async {
  return ref.watch(dashboardRepositoryProvider).fetchStats(gymId);
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();
    final gymId = profile.gymId;
    final asyncStats = ref.watch(dashboardStatsProvider(gymId));
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: () => ref.read(authActionsProvider).signOut()),
        ],
      ),
      body: asyncStats.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardStatsProvider(gymId).future),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome back, ${profile.fullName ?? profile.email ?? 'there'}', style: txt.displayMedium),
              const SizedBox(height: 24),
              _stats(stats),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
         loading: () => const AppLoadingState(),
         error: (e, _) => AppErrorState(message: 'Failed to load dashboard', onRetry: () => ref.refresh(dashboardStatsProvider(gymId).future)),
       ),
     );
  }

  Widget _stats(DashboardStats s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cards = [
          StatCard(data: StatCardData(title: 'Members', value: '${s.totalMembers}', icon: const Icon(Icons.groups_outlined))),
          StatCard(data: StatCardData(title: 'Checked in today', value: '${s.checkedInToday}', icon: const Icon(Icons.qr_code_scanner))),
          StatCard(data: StatCardData(title: 'Red list open', value: '${s.redListOpen}', icon: const Icon(Icons.warning_amber_outlined))),
          StatCard(data: StatCardData(title: 'Renewals due', value: '${s.renewalsDue}', icon: const Icon(Icons.currency_exchange))),
        ];
        final cols = (width / 240).floor().clamp(1, 4);
        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.6),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}
