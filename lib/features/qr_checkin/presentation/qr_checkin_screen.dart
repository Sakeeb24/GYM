// lib/features/qr_checkin/presentation/qr_checkin_screen.dart
import 'package:flutter/material.dart';
import 'package:liftflow/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../attendance_repository.dart';
import '../attendance_result_view.dart';
import '../qr_scanner_view.dart';

class QrCheckInScreen extends StatefulWidget {
  const QrCheckInScreen({super.key});

  @override
  State<QrCheckInScreen> createState() => _QrCheckInScreenState();
}

class _QrCheckInScreenState extends State<QrCheckInScreen> {
  final AttendanceRepository _repo = EdgeFunctionAttendanceRepository();
  AttendanceCheckInResult _result = const AttendanceCheckInResult(outcome: CheckInOutcome.loading);
  bool _scanning = true;

  static bool get _devSimulate => const bool.fromEnvironment('SIMULATE_QR') || Env.isDev;

  void _onDetect(String payload) {
    if (!_scanning) return;
    setState(() => _scanning = false);
    _repo.recordCheckIn(payload).then((result) {
      if (!mounted) return;
      setState(() => _result = result);
    });
  }

  void _reset() => setState(() {
        _result = const AttendanceCheckInResult(outcome: CheckInOutcome.loading);
        _scanning = true;
      });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    if (!_scanning) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'CHECK-IN RESULT',
            style: AppTypography.labelAthletic.copyWith(
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: AttendanceResultView(
            outcome: _result.outcome,
            streak: _result.streak,
            onDismiss: _reset,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 22, color: isDark ? AppColors.brand : AppColors.brandDark),
            const SizedBox(width: 10),
            Text(
              'SCAN GYM QR PASS',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 14,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: QrScannerView(
                key: const ValueKey('scanner'),
                onDetected: _onDetect,
                simulating: _devSimulate,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Position the camera over the gym entry QR code',
              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
