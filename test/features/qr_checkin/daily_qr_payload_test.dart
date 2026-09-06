// test/features/qr_checkin/daily_qr_payload_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/features/qr_checkin/attendance_repository.dart';

void main() {
  group('Daily Attendance QR Payload Generator', () {
    const gymId = '11111111-1111-1111-1111-111111111111';
    const secret = 'super_secure_qr_secret_123';

    test('buildDailyQrPayload generates signed two-part token', () {
      final payload = EdgeFunctionAttendanceRepository.buildDailyQrPayload(
        gymId: gymId,
        signingSecret: secret,
        date: DateTime(2026, 9, 2),
      );

      expect(payload, isNotEmpty);
      expect(payload.contains('.'), isTrue);

      final parts = payload.split('.');
      expect(parts.length, equals(2));

      final bodyB64 = parts[0];
      final sigB64 = parts[1];

      expect(bodyB64, isNotEmpty);
      expect(sigB64, isNotEmpty);

      // Decode body
      String normalizedB64 = bodyB64.replaceAll('-', '+').replaceAll('_', '/');
      while (normalizedB64.length % 4 != 0) {
        normalizedB64 += '=';
      }
      final decodedJson = utf8.decode(base64.decode(normalizedB64));
      final map = jsonDecode(decodedJson) as Map<String, dynamic>;

      expect(map['gym_id'], equals(gymId));
      expect(map['valid_date'], equals('2026-09-02'));
      expect(map['exp'], isNotNull);
      expect(map['issued_at'], isNotNull);
      expect(map['nonce'], isNotNull);
    });

    test('buildDailyQrPayload produces unique nonces on separate calls', () {
      final p1 = EdgeFunctionAttendanceRepository.buildDailyQrPayload(gymId: gymId, signingSecret: secret);
      final p2 = EdgeFunctionAttendanceRepository.buildDailyQrPayload(gymId: gymId, signingSecret: secret);

      expect(p1, isNot(equals(p2)));
    });
  });
}
