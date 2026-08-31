// lib/features/auth/presentation/verify_gym_screen.dart
// Registration Step 2: Real Camera QR Gym Verification
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../member_activation_repository.dart';
import 'auth_widgets.dart';

class VerifyGymScreen extends ConsumerStatefulWidget {
  final String fullName;
  final String phone;

  const VerifyGymScreen({
    super.key,
    required this.fullName,
    required this.phone,
  });

  @override
  ConsumerState<VerifyGymScreen> createState() => _VerifyGymScreenState();
}

class _VerifyGymScreenState extends ConsumerState<VerifyGymScreen> {
  MobileScannerController? _scannerController;
  bool _validating = false;
  String? _scannedToken;
  ValidatedGymActivation? _verifiedGym;
  String? _error;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_validating || _verifiedGym != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    _validateToken(rawValue.trim());
  }

  Future<void> _validateToken(String rawPayload) async {
    setState(() {
      _validating = true;
      _error = null;
    });

    try {
      final repo = ref.read(memberActivationRepositoryProvider);
      final result = await repo.validateActivationToken(rawPayload);

      // Extract cleaned token
      String token = rawPayload;
      if (token.startsWith('liftflow://member-activation/')) {
        token = token.replaceFirst('liftflow://member-activation/', '').trim();
      } else if (token.contains('/activate/')) {
        token = token.split('/activate/')[1].trim();
      }

      if (mounted) {
        setState(() {
          _scannedToken = token;
          _verifiedGym = result;
          _validating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorMapper.toUserMessage(e);
          _validating = false;
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _error = null;
      _scannedToken = null;
      _verifiedGym = null;
      _validating = false;
    });
  }

  void _proceedToCredentials() {
    if (_scannedToken == null || _verifiedGym == null) return;

    context.push('/account-setup', extra: {
      'fullName': widget.fullName,
      'phone': widget.phone,
      'activationToken': _scannedToken!,
      'gymName': _verifiedGym!.gymName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'VERIFY GYM',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          if (_verifiedGym == null && _scannerController != null)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _torchOn ? AppColors.brand : cs.onSurfaceVariant,
              ),
              onPressed: () async {
                await _scannerController?.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthStepIndicator(current: 2, total: 3),
                  const SizedBox(height: 20),

                  if (_verifiedGym != null) ...[
                    // ── Verified Success State ───────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: AppRadii.r16,
                        border: Border.all(color: AppColors.success.withAlpha(120), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(35),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'GYM VERIFIED ✓',
                            style: AppTypography.labelAthletic.copyWith(
                              color: AppColors.success,
                              fontSize: 13,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _verifiedGym!.gymName,
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Authorized by Gym Owner / Staff',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withAlpha(80),
                              borderRadius: AppRadii.r8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user_rounded, size: 16, color: AppColors.brand),
                                const SizedBox(width: 8),
                                Text(
                                  'Ready to setup account for ${widget.fullName}',
                                  style: AppTypography.bodySmall.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'Continue to Credentials',
                      onPressed: _proceedToCredentials,
                      fullWidth: true,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _resetScanner,
                      child: Text(
                        'Scan Different QR',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else ...[
                    // ── Camera Scanner View ──────────────────────────────
                    Text(
                      'Scan Gym Activation QR',
                      style: AppTypography.headlineLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Step 2 of 3: Ask your gym owner to display the member activation QR code on their screen.',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),

                    // Camera Surface with HUD
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 290,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.brand.withAlpha(80), width: 1.5),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_scannerController != null)
                              MobileScanner(
                                controller: _scannerController!,
                                onDetect: _onDetect,
                                errorBuilder: (ctx, error, child) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.camera_alt_outlined, color: AppColors.warning, size: 40),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Camera unavailable or permission denied.',
                                            textAlign: TextAlign.center,
                                            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              _scannerController?.start();
                                            },
                                            icon: const Icon(Icons.refresh_rounded, size: 16),
                                            label: const Text('Retry Camera'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                            // Athletic HUD Target Frame
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.brand.withAlpha(100), width: 1.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(top: 0, left: 0, child: _CornerBracket(isTop: true, isLeft: true)),
                                  Positioned(top: 0, right: 0, child: _CornerBracket(isTop: true, isLeft: false)),
                                  Positioned(bottom: 0, left: 0, child: _CornerBracket(isTop: false, isLeft: true)),
                                  Positioned(bottom: 0, right: 0, child: _CornerBracket(isTop: false, isLeft: false)),
                                  if (_validating)
                                    const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Top status badge
                            Positioned(
                              top: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(200),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.brand.withAlpha(80)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _validating ? Icons.hourglass_top_rounded : Icons.qr_code_scanner_rounded,
                                      color: AppColors.brand,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _validating ? 'VALIDATING GYM...' : 'ALIGN QR INSIDE FRAME',
                                      style: AppTypography.labelAthletic.copyWith(
                                        color: AppColors.brand,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_error != null) ...[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Try Again',
                        variant: AppButtonVariant.outlined,
                        onPressed: _resetScanner,
                        fullWidth: true,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerBracket({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: AppColors.brand, width: 3.5) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: AppColors.brand, width: 3.5) : BorderSide.none,
          left: isLeft ? const BorderSide(color: AppColors.brand, width: 3.5) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: AppColors.brand, width: 3.5) : BorderSide.none,
        ),
      ),
    );
  }
}
