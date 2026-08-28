// lib/features/qr_checkin/qr_scanner_view.dart
// Camera-agnostic QR scan surface. The default implementation is a dev
// simulator so the whole UI flow is testable without a device. On a real
// device, swap the body for `MobileScanner(onDetect: ...)` behind this same
// interface — the security-critical logic lives server-side (recordAttendance
// edge function with HMAC verification).
import 'package:flutter/material.dart';
import 'package:liftflow/config/env.dart';
import '../../core/widgets/app_button.dart';

typedef OnQrDetected = void Function(String payload);

class QrScannerView extends StatelessWidget {
  final OnQrDetected onDetected;
  final bool simulating;

  const QrScannerView({super.key, required this.onDetected, this.simulating = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withAlpha(64)),
      ),
      child: Stack(children: [
        if (simulating)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton(
                text: 'Simulate scan (dev)',
                variant: AppButtonVariant.outlined,
                onPressed: () => _simulate(),
              ),
            ),
          ),
        const Align(
          alignment: Alignment.center,
          child: Icon(Icons.qr_code_scanner, size: 80, color: Colors.white24),
        ),
      ]),
    );
  }

  void _simulate() {
    if (!Env.isDev) return;
    const demo = '{"gym_id":"00000000-0000-0000-0000-00000000000A","nonce":"demo","exp":9999999999}';
    onDetected(demo);
  }
}

