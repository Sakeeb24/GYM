// lib/features/qr_checkin/attendance_repository.dart
import 'package:uuid/uuid.dart';
import '../../core/services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a QR check-in attempt. The server (recordAttendance edge function)
/// is the source of truth; this enum drives the UI.
enum CheckInOutcome {
  success,       // attendance recorded
  duplicate,     // already scanned within the grace window
  denied,        // expired/paused/canceled membership, or wrong gym
  error,         // network / server failure
  loading,
}

/// Thin client of the server-side `recordAttendance` edge function. The client
/// NEVER writes attendance directly (rule: never trust client).
abstract class AttendanceRepository {
  Future<CheckInOutcome> recordCheckIn(String qrPayload);
}

class EdgeFunctionAttendanceRepository implements AttendanceRepository {
  final SupabaseClient _client;
  EdgeFunctionAttendanceRepository([SupabaseClient? client]) : _client = client ?? AppSupabase.client;

  @override
  Future<CheckInOutcome> recordCheckIn(String qrPayload) async {
    final idem = Uuid().v4();
    final res = await _client.functions.invoke('recordAttendance', body: {
      'qrPayload': qrPayload,
      'source': 'qr_self',
      'idempotencyKey': idem,
    });
      'qrPayload': qrPayload,
      'source': 'qr_self',
      'idempotencyKey': idem,
    });
    if (res.error != null) return CheckInOutcome.error;
    if (res.data == null) return CheckInOutcome.error;
    final body = res.data as Map<String, dynamic>;
    if (body['duplicate'] == true) return CheckInOutcome.duplicate;
    final err = body['error'] as String? ?? '';
    if (err.isNotEmpty && err.toLowerCase().contains('denied')) return CheckInOutcome.denied;
    if (err.isNotEmpty) return CheckInOutcome.error;
    return CheckInOutcome.success;
  }
}

