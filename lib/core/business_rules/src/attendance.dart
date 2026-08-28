import 'package:flutter/foundation.dart';

/// One recorded check-in (mirrors the attendance row).
@immutable
class Attendance {
  final String memberId;
  final String gymId;
  final DateTime checkInAt;
  final String? idempotencyKey;
  final String source;

  const Attendance({
    required this.memberId,
    required this.gymId,
    required this.checkInAt,
    this.idempotencyKey,
    this.source = 'qr_self',
  });
}
