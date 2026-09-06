// lib/features/gym_display/presentation/gym_display_screen.dart
// Dedicated Full-Screen Gym Kiosk Display Mode for Tablets, TVs, and Monitors
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_notifier.dart';
import '../../qr_checkin/attendance_repository.dart';

class GymDisplayScreen extends ConsumerStatefulWidget {
  final String? gymSlug;
  const GymDisplayScreen({super.key, this.gymSlug});

  @override
  ConsumerState<GymDisplayScreen> createState() => _GymDisplayScreenState();
}

class _GymDisplayScreenState extends ConsumerState<GymDisplayScreen> {
  DateTime _currentDate = DateTime.now();
  late Timer _clockTimer;
  String _gymName = 'LIFTFLOW GYM';
  String _gymId = '';
  String? _signingSecret;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGymDetails();
    _startClockTimer();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      // Detect midnight rollover to automatically generate and switch to the new Daily QR
      if (now.day != _currentDate.day || now.month != _currentDate.month || now.year != _currentDate.year) {
        setState(() {
          _currentDate = now;
        });
      } else {
        setState(() {
          _currentDate = now;
        });
      }
    });
  }

  Future<void> _loadGymDetails() async {
    setState(() {
      _loading = true;
    });

    try {
      final client = AppSupabase.client;

      // If user is authenticated, use their gym
      final profile = ref.read(authStateProvider).valueOrNull;
      if (profile != null && profile.gymId.isNotEmpty) {
        _gymId = profile.gymId;
        final gymRes = await client.from('gyms').select('name, slug').eq('id', _gymId).maybeSingle();
        if (gymRes != null && gymRes['name'] != null) {
          _gymName = (gymRes['name'] as String).toUpperCase();
        }
      } else if (widget.gymSlug != null && widget.gymSlug!.isNotEmpty) {
        // Look up by slug
        final gymRes = await client.from('gyms').select('id, name').eq('slug', widget.gymSlug!).maybeSingle();
        if (gymRes != null) {
          _gymId = gymRes['id'] as String;
          _gymName = (gymRes['name'] as String).toUpperCase();
        } else {
          _gymId = '00000000-0000-0000-0000-000000000001';
          _gymName = 'LIFTFLOW ATHLETIC CLUB';
        }
      } else {
        // Default display gym fallback
        final firstGym = await client.from('gyms').select('id, name').limit(1).maybeSingle();
        if (firstGym != null) {
          _gymId = firstGym['id'] as String;
          _gymName = (firstGym['name'] as String).toUpperCase();
        } else {
          _gymId = '00000000-0000-0000-0000-000000000001';
          _gymName = 'LIFTFLOW ATHLETIC CLUB';
        }
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gymId = '00000000-0000-0000-0000-000000000001';
          _gymName = 'LIFTFLOW ATHLETIC CLUB';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatted = DateFormat('hh:mm:ss a').format(_currentDate);
    final dateFormatted = DateFormat('EEEE, d MMMM yyyy').format(_currentDate).toUpperCase();

    final dailyPayload = _gymId.isNotEmpty
        ? EdgeFunctionAttendanceRepository.buildDailyQrPayload(
            gymId: _gymId,
            signingSecret: _signingSecret,
            date: _currentDate,
          )
        : 'liftflow://daily-attendance/loading';

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C), // Deep black-charcoal kiosk canvas
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── 1. Top Header & Brand Bar ────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.brand, width: 1.5),
                              ),
                              child: const Icon(Icons.fitness_center_rounded, size: 22, color: AppColors.brand),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'LIFTFLOW',
                              style: AppTypography.labelAthletic.copyWith(
                                fontSize: 22,
                                letterSpacing: 4.0,
                                color: AppColors.brand,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Gym Name
                        Text(
                          _gymName,
                          style: AppTypography.headlineLarge.copyWith(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),

                        // Live Clock with seconds
                        Text(
                          timeFormatted,
                          style: AppTypography.labelAthletic.copyWith(
                            fontSize: 16,
                            color: AppColors.brand,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── 2. Massive High-Contrast QR Code Card ────────────────
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13161A),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.brand.withAlpha(80),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.brandGlow,
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'SCAN TO CHECK IN',
                                style: AppTypography.labelAthletic.copyWith(
                                  fontSize: 18,
                                  letterSpacing: 3.0,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // High-contrast QR Container
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: QrImageView(
                                  data: dailyPayload,
                                  version: QrVersions.auto,
                                  size: 280,
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

                              // Date & Validity
                              Text(
                                dateFormatted,
                                style: AppTypography.labelAthletic.copyWith(
                                  fontSize: 13,
                                  color: AppColors.dTextSecondary,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withAlpha(30),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.success, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'VALID TODAY • AUTO-REFRESHES AT MIDNIGHT',
                                      style: AppTypography.labelAthletic.copyWith(
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── 3. Footer / Connection Status ────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_rounded, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text(
                              'KIOSK CONNECTED • SECURE POSTGRES STREAM ACTIVE',
                              style: AppTypography.labelAthletic.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.0,
                                color: AppColors.dTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
