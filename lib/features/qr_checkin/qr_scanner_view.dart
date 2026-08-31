// lib/features/qr_checkin/qr_scanner_view.dart
// Athletic Precision QR Scanner HUD Surface with Live MobileScanner Stream
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';

typedef OnQrDetected = void Function(String payload);

class QrScannerView extends StatefulWidget {
  final OnQrDetected onDetected;
  final bool simulating;

  const QrScannerView({
    super.key,
    required this.onDetected,
    this.simulating = false,
  });

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  MobileScannerController? _controller;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    } catch (_) {
      // Graceful fallback if camera hardware is unavailable on desktop/simulator
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        widget.onDetected(rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07090C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brand.withAlpha(50), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Live MobileScanner Camera Stream
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _handleBarcode,
              errorBuilder: (context, error, child) {
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
                          onPressed: () => _controller?.start(),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry Camera'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // 2. Target Frame HUD
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
                  Positioned(top: 0, left: 0, child: _CornerBracket(isTop: true, isLeft: true)),
                  Positioned(top: 0, right: 0, child: _CornerBracket(isTop: true, isLeft: false)),
                  Positioned(bottom: 0, left: 0, child: _CornerBracket(isTop: false, isLeft: true)),
                  Positioned(bottom: 0, right: 0, child: _CornerBracket(isTop: false, isLeft: false)),
                ],
              ),
            ),
          ),

          // 3. Top guidance text
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

          // 4. Torch Toggle Control
          if (_controller != null)
            Positioned(
              top: 18,
              right: 18,
              child: IconButton(
                icon: Icon(
                  _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: _torchOn ? AppColors.brand : Colors.white70,
                ),
                onPressed: () async {
                  await _controller?.toggleTorch();
                  setState(() => _torchOn = !_torchOn);
                },
              ),
            ),

          // 5. Simulation Button (Dev only)
          if (widget.simulating && Env.isDev)
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
    widget.onDetected(demo);
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
