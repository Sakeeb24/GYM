// lib/features/qr_checkin/presentation/qr_checkin_screen.dart
import 'package:flutter/material.dart';
import 'package:liftflow/config/env.dart';
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
  CheckInOutcome _outcome = CheckInOutcome.loading;
  bool _scanning = true;

  static bool get _devSimulate => const bool.fromEnvironment('SIMULATE_QR') || Env.isDev;

  void _onDetect(String payload) {
    if (!_scanning) return;
    setState(() => _scanning = false);
    _repo.recordCheckIn(payload).then((outcome) {
      if (!mounted) return;
      setState(() => _outcome = outcome);
    });
  }

  void _reset() => setState(() {
        _outcome = CheckInOutcome.loading;
        _scanning = true;
      });

  @override
  Widget build(BuildContext context) {
    if (!_scanning) {
      return Scaffold(
        appBar: AppBar(title: const Text('Check-in')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AttendanceResultView(outcome: _outcome, onDismiss: _reset),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Scan guest QR')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Expanded(
            child: QrScannerView(
              key: const ValueKey('scanner'),
              onDetected: _onDetect,
              simulating: _devSimulate,
            ),
          ),
          const SizedBox(height: 16),
          Text('Point the camera at the member QR code',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
