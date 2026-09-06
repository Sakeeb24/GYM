import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/supabase_client.dart';
import '../../core/utils/app_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a QR check-in attempt. The server (recordAttendance edge function)
/// is the source of truth; this drives the UI.
enum CheckInOutcome {
  success,       // attendance recorded
  duplicate,     // already scanned within the grace window
  denied,        // expired/paused/canceled membership, or wrong gym
  error,         // network / server failure
  loading,
}

class AttendanceCheckInResult {
  final CheckInOutcome outcome;
  final int streak;
  final int longestStreak;
  final String? message;

  const AttendanceCheckInResult({
    required this.outcome,
    this.streak = 1,
    this.longestStreak = 1,
    this.message,
  });

  factory AttendanceCheckInResult.fromOutcome(CheckInOutcome outcome, {int streak = 1, String? message}) {
    return AttendanceCheckInResult(outcome: outcome, streak: streak, message: message);
  }
}

/// Thin client of the server-side `recordAttendance` edge function.
abstract class AttendanceRepository {
  Future<AttendanceCheckInResult> recordCheckIn(String qrPayload);
}

class EdgeFunctionAttendanceRepository implements AttendanceRepository {
  final SupabaseClient? _client;
  EdgeFunctionAttendanceRepository([SupabaseClient? client]) : _client = client;

  SupabaseClient get client => _client ?? AppSupabase.client;

  /// Constructs a signed Daily Attendance QR payload (System B) valid for the calendar day.
  static String buildDailyQrPayload({
    required String gymId,
    String? signingSecret,
    DateTime? date,
  }) {
    final d = date ?? DateTime.now();
    final validDate = DateFormat('yyyy-MM-dd').format(d);
    final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);
    final exp = endOfDay.millisecondsSinceEpoch ~/ 1000;
    final issuedAt = d.millisecondsSinceEpoch ~/ 1000;
    final secret = signingSecret ?? gymId;

    final payloadMap = {
      'gym_id': gymId,
      'valid_date': validDate,
      'exp': exp,
      'issued_at': issuedAt,
      'nonce': const Uuid().v4(),
    };

    final jsonStr = jsonEncode(payloadMap);
    final bodyB64 = base64Url.encode(utf8.encode(jsonStr)).replaceAll('=', '');

    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(bodyB64));
    final sigB64 = base64Url.encode(digest.bytes).replaceAll('=', '');

    return '$bodyB64.$sigB64';
  }

  @override
  Future<AttendanceCheckInResult> recordCheckIn(String qrPayload) async {
    final idem = const Uuid().v4();
    try {
      final res = await client.functions.invoke('recordAttendance', body: {
        'qrPayload': qrPayload,
        'source': 'qr_self',
        'idempotencyKey': idem,
      });
      if (res.data == null) {
        return AttendanceCheckInResult.fromOutcome(CheckInOutcome.error, message: 'Server communication error');
      }
      final body = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);

      if (body['duplicate'] == true) {
        return AttendanceCheckInResult.fromOutcome(CheckInOutcome.duplicate, message: 'Pass already scanned recently');
      }

      final err = body['error'] as String? ?? '';
      if (err.isNotEmpty) {
        if (err.toLowerCase().contains('denied') || err.toLowerCase().contains('inactive') || err.toLowerCase().contains('expired')) {
          return AttendanceCheckInResult.fromOutcome(CheckInOutcome.denied, message: err);
        }
        return AttendanceCheckInResult.fromOutcome(CheckInOutcome.error, message: err);
      }

      final streak = (body['streak'] as num?)?.toInt() ?? 1;
      final longest = (body['longest_streak'] as num?)?.toInt() ?? streak;

      return AttendanceCheckInResult(
        outcome: CheckInOutcome.success,
        streak: streak,
        longestStreak: longest,
      );
    } catch (e) {
      final msg = AppErrorMapper.toUserMessage(e);
      if (msg.toLowerCase().contains('denied') ||
          msg.toLowerCase().contains('inactive') ||
          msg.toLowerCase().contains('expired') ||
          msg.toLowerCase().contains('forbidden')) {
        return AttendanceCheckInResult.fromOutcome(CheckInOutcome.denied, message: msg);
      }
      return AttendanceCheckInResult.fromOutcome(CheckInOutcome.error, message: msg);
    }
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return EdgeFunctionAttendanceRepository();
});
