// lib/features/auth/presentation/splash_screen.dart
// Premium Athletic Splash Screen & Session Resolver
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../auth_notifier.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
    _resolveSession();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _resolveSession() async {
    // Give animation brief moment to feel polished
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final profileAsync = ref.read(authStateProvider);
    final profile = profileAsync.valueOrNull;

    if (profile != null) {
      context.go('/app');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dCanvas,
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 0.8,
                  colors: [
                    Color(0x1A00D2FF), // 10% Cyan glow
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dumbbell Icon in glowing container
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.dSurfaceAlt,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.brand.withAlpha(80),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.brandGlow,
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fitness_center_rounded,
                          size: 40,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App Title
                    Text(
                      'LIFTFLOW',
                      style: AppTypography.labelAthletic.copyWith(
                        fontSize: 28,
                        letterSpacing: 4.5,
                        color: AppColors.brand,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Athletic Tagline
                    Text(
                      'TRAIN HARD. TRACK EVERYTHING.',
                      style: AppTypography.labelAthletic.copyWith(
                        fontSize: 12,
                        letterSpacing: 2.0,
                        color: AppColors.dTextSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Subtle loading indicator
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brand.withAlpha(180),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Footer
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'ENTERPRISE GYM RETENTION PLATFORM',
                style: AppTypography.labelAthletic.copyWith(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: AppColors.dTextTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
