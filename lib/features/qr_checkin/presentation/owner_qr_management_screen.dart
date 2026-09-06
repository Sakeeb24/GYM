// lib/features/qr_checkin/presentation/owner_qr_management_screen.dart
// Dual QR Management Screen (Monthly Member Activation + Daily Attendance QR)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../auth/auth_notifier.dart';
import '../../auth/member_activation_repository.dart';
import '../attendance_repository.dart';

class OwnerQrManagementScreen extends ConsumerStatefulWidget {
  const OwnerQrManagementScreen({super.key});

  @override
  ConsumerState<OwnerQrManagementScreen> createState() => _OwnerQrManagementScreenState();
}

class _OwnerQrManagementScreenState extends ConsumerState<OwnerQrManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MemberActivationTokenResponse? _activationToken;
  bool _loadingActivation = true;
  String? _activationError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMonthlyActivation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMonthlyActivation() async {
    setState(() {
      _loadingActivation = true;
      _activationError = null;
    });

    try {
      final repo = ref.read(memberActivationRepositoryProvider);
      final res = await repo.createActivationToken();
      if (mounted) {
        setState(() {
          _activationToken = res;
          _loadingActivation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activationError = e.toString();
          _loadingActivation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const AppLoadingState();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gymId = profile.gymId;

    final todayDate = DateTime.now();
    final todayFormatted = DateFormat('EEEE, d MMMM yyyy').format(todayDate);
    final monthFormatted = DateFormat('MMMM yyyy').format(todayDate);

    final dailyPayload = EdgeFunctionAttendanceRepository.buildDailyQrPayload(
      gymId: gymId,
      date: todayDate,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'QR MANAGEMENT',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brand,
          labelColor: isDark ? AppColors.brand : AppColors.brandDark,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: AppTypography.labelAthletic.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "TODAY'S ATTENDANCE"),
            Tab(text: "MONTHLY ACTIVATION"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Daily Attendance QR ─────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dSurface : AppColors.lSurface,
                    borderRadius: AppRadii.card,
                    border: Border.all(
                      color: isDark ? AppColors.brand.withAlpha(60) : AppColors.brandDark.withAlpha(60),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.brandGlow,
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SYSTEM B • DAILY ATTENDANCE QR',
                          style: AppTypography.labelAthletic.copyWith(
                            fontSize: 10,
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        todayFormatted,
                        style: AppTypography.headlineLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Existing members scan this code daily at the gym to check in.',
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // QR Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: dailyPayload,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            'HMAC Signed • Valid Today Until Midnight',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Open Fullscreen Gym Kiosk Display',
                  icon: const Icon(Icons.tv_rounded),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Direct display URL: /display/attendance (suitable for tablets/monitors)'),
                      ),
                    );
                  },
                  fullWidth: true,
                ),
              ],
            ),
          ),

          // ── Tab 2: Monthly Activation QR ───────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: _loadingActivation
                ? const Center(child: Padding(padding: EdgeInsets.all(40), child: AppLoadingState()))
                : _activationError != null
                    ? AppErrorState(
                        message: _activationError!,
                        onRetry: _loadMonthlyActivation,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.dSurface : AppColors.lSurface,
                              borderRadius: AppRadii.card,
                              border: Border.all(
                                color: isDark ? AppColors.brand.withAlpha(60) : AppColors.brandDark.withAlpha(60),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'SYSTEM A • MONTHLY ACTIVATION QR',
                                    style: AppTypography.labelAthletic.copyWith(
                                      fontSize: 10,
                                      color: isDark ? AppColors.brand : AppColors.brandDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  monthFormatted.toUpperCase(),
                                  style: AppTypography.headlineLarge.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Prospective members scan this QR during account creation to verify gym membership.',
                                  style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),

                                // QR Box
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: QrImageView(
                                    data: _activationToken?.qrPayload ?? 'liftflow://member-activation/invalid',
                                    version: QrVersions.auto,
                                    size: 220,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.black,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.brand),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Valid for all new members during $monthFormatted',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isDark ? AppColors.brand : AppColors.brandDark,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            text: 'Copy Activation Token Key',
                            icon: const Icon(Icons.copy_rounded),
                            variant: AppButtonVariant.secondary,
                            onPressed: () {
                              if (_activationToken?.activationToken != null) {
                                Clipboard.setData(ClipboardData(text: _activationToken!.activationToken));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Monthly activation token copied to clipboard')),
                                );
                              }
                            },
                            fullWidth: true,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
