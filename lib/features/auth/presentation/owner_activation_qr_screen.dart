// lib/features/auth/presentation/owner_activation_qr_screen.dart
// Owner Screen: Generate & Display Short-Lived Single-Use Member Activation QR
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../member_activation_repository.dart';

class OwnerActivationQrScreen extends ConsumerStatefulWidget {
  const OwnerActivationQrScreen({super.key});

  @override
  ConsumerState<OwnerActivationQrScreen> createState() => _OwnerActivationQrScreenState();
}

class _OwnerActivationQrScreenState extends ConsumerState<OwnerActivationQrScreen> {
  MemberActivationTokenResponse? _tokenData;
  bool _loading = true;
  String? _error;
  int _remainingSeconds = 60;
  int _totalLifetime = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateToken() async {
    _countdownTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(memberActivationRepositoryProvider);
      final res = await repo.createActivationToken();

      if (mounted) {
        final remaining = res.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 3600);
        setState(() {
          _tokenData = res;
          _totalLifetime = res.lifetimeSeconds > 0 ? res.lifetimeSeconds : (remaining > 0 ? remaining : 60);
          _remainingSeconds = remaining > 0 ? remaining : _totalLifetime;
          _loading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorMapper.toUserMessage(e);
          _loading = false;
        });
      }
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        if (mounted) setState(() {});
      }
    });
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpired = _remainingSeconds <= 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'ACTIVATE NEW MEMBER',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Generate New QR',
            onPressed: _loading ? null : _generateToken,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _loading
                  ? const AppLoadingState()
                  : _error != null
                      ? AppErrorState(
                          message: _error!,
                          onRetry: _generateToken,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Text(
                              'Scan to Join',
                              textAlign: TextAlign.center,
                              style: AppTypography.headlineLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ask the prospective member to open Create Account and scan this activation code.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 20),

                            // QR Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: AppRadii.r16,
                                border: Border.all(
                                  color: isExpired
                                      ? AppColors.error.withAlpha(120)
                                      : (_remainingSeconds < 15
                                          ? AppColors.warning.withAlpha(120)
                                          : AppColors.brand.withAlpha(120)),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Gym badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.brand.withAlpha(20) : AppColors.brandContainer,
                                      borderRadius: AppRadii.r8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.fitness_center_rounded, size: 14, color: AppColors.brand),
                                        const SizedBox(width: 6),
                                        Text(
                                          _tokenData?.gymName ?? 'LiftFlow Gym',
                                          style: AppTypography.labelAthletic.copyWith(
                                            fontSize: 11,
                                            color: isDark ? AppColors.brand : AppColors.brandDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // QR Code or Expired Placeholder
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 240,
                                      height: 240,
                                      color: Colors.white,
                                      padding: const EdgeInsets.all(12),
                                      child: isExpired
                                          ? Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.timer_off_outlined,
                                                    color: AppColors.error,
                                                    size: 48,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'QR EXPIRED',
                                                    style: AppTypography.titleMedium.copyWith(
                                                      color: Colors.black,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Tap refresh to generate a new QR',
                                                    textAlign: TextAlign.center,
                                                    style: AppTypography.bodySmall.copyWith(
                                                      color: Colors.black54,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : QrImageView(
                                              data: _tokenData!.qrPayload,
                                              version: QrVersions.auto,
                                              size: 216,
                                              backgroundColor: Colors.white,
                                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Timer status
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isExpired
                                                ? Icons.error_outline_rounded
                                                : (_remainingSeconds < 15 ? Icons.warning_amber_rounded : Icons.timer_outlined),
                                            size: 16,
                                            color: isExpired
                                                ? AppColors.error
                                                : (_remainingSeconds < 15 ? AppColors.warning : AppColors.brand),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isExpired ? 'QR Code Expired' : 'Expires in ${_formatTimer(_remainingSeconds)}',
                                            style: AppTypography.bodySmall.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: isExpired
                                                  ? AppColors.error
                                                  : (_remainingSeconds < 15 ? AppColors.warning : cs.onSurface),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Single-use',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Lifetime Progress Bar
                                  AppProgressBar(
                                    progress: _totalLifetime > 0 ? (_remainingSeconds / _totalLifetime).clamp(0.0, 1.0) : 0.0,
                                    height: 4,
                                    color: isExpired
                                        ? AppColors.error
                                        : (_remainingSeconds < 15 ? AppColors.warning : AppColors.brand),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Actions
                            AppButton(
                              text: isExpired ? 'Generate New QR' : 'Refresh QR Code',
                              onPressed: _generateToken,
                              fullWidth: true,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                            ),
                            const SizedBox(height: 12),

                            AppButton(
                              text: 'Done / Close',
                              variant: AppButtonVariant.outlined,
                              onPressed: () => context.pop(),
                              fullWidth: true,
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
