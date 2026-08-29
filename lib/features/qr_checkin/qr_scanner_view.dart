// lib/features/qr_checkin/qr_scanner_view.dart
// Athletic Precision QR Scanner HUD Surface
import 'package:flutter/material.dart';
import '../../config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';

typedef OnQrDetected = void Function(String payload);

class QrScannerView extends StatelessWidget {
  final OnQrDetected onDetected;
  final bool simulating;

  const QrScannerView({super.key, required this.onDetected, this.simulating = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07090C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brand.withAlpha(50), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background grid / target effect
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.brand.withAlpha(80), width: 1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Corner brackets
                  Positioned(top: 0, left: 0, child: _CornerBracket(isTop: true, isLeft: true)),
                  Positioned(top: 0, right: 0, child: _CornerBracket(isTop: true, isLeft: false)),
                  Positioned(bottom: 0, left: 0, child: _CornerBracket(isTop: false, isLeft: true)),
                  Positioned(bottom: 0, right: 0, child: _CornerBracket(isTop: false, isLeft: false)),
                  const Center(
                    child: Icon(Icons.qr_code_scanner_rounded, size: 72, color: AppColors.brandGlow),
                  ),
                ],
              ),
            ),
          ),

          // Top guidance text
          Positioned(
            top: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.brand.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.center_focus_strong_rounded, color: AppColors.brand, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'ALIGN QR CODE WITHIN FRAME',
                    style: AppTypography.labelAthletic.copyWith(
                      color: AppColors.brand,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Simulation Button (Dev only)
          if (simulating)
            Positioned(
              bottom: 20,
              child: AppButton(
                text: 'SIMULATE SCAN (DEV)',
                variant: AppButtonVariant.outlined,
                onPressed: _simulate,
                icon: const Icon(Icons.bolt, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  void _simulate() {
    if (!Env.isDev) return;
    const demo = '{"gym_id":"00000000-0000-0000-0000-00000000000A","nonce":"demo","exp":9999999999}';
    onDetected(demo);
  }
}

class _CornerBracket extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerBracket({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: AppColors.brand, width: 3) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: AppColors.brand, width: 3) : BorderSide.none,
          left: isLeft ? const BorderSide(color: AppColors.brand, width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: AppColors.brand, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}
