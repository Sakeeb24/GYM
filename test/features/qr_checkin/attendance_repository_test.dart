// test/features/qr_checkin/attendance_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/features/qr_checkin/attendance_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockFunctionsClient mockFunctions;
  late EdgeFunctionAttendanceRepository repository;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockFunctions = MockFunctionsClient();
    when(() => mockSupabase.functions).thenReturn(mockFunctions);
    repository = EdgeFunctionAttendanceRepository(mockSupabase);
  });

  group('EdgeFunctionAttendanceRepository Tests', () {
    test('Successful check-in returns success outcome with streak data', () async {
      when(() => mockFunctions.invoke(
        'recordAttendance',
        body: any(named: 'body'),
      )).thenAnswer((_) async => FunctionResponse(
        data: {
          'streak': 5,
          'longest_streak': 10,
          'duplicate': false,
        },
        status: 200,
      ));

      final result = await repository.recordCheckIn('valid_qr_payload');
      expect(result.outcome, equals(CheckInOutcome.success));
      expect(result.streak, equals(5));
      expect(result.longestStreak, equals(10));
    });

    test('Duplicate scan returns duplicate outcome', () async {
      when(() => mockFunctions.invoke(
        'recordAttendance',
        body: any(named: 'body'),
      )).thenAnswer((_) async => FunctionResponse(
        data: {
          'duplicate': true,
        },
        status: 200,
      ));

      final result = await repository.recordCheckIn('duplicate_qr_payload');
      expect(result.outcome, equals(CheckInOutcome.duplicate));
      expect(result.message, equals('Pass already scanned recently'));
    });

    test('Denied membership returns denied outcome with server message', () async {
      when(() => mockFunctions.invoke(
        'recordAttendance',
        body: any(named: 'body'),
      )).thenThrow(
        const FunctionException(
          status: 403,
          details: {'error': 'Check-in denied: membership is expired'},
        ),
      );

      final result = await repository.recordCheckIn('expired_qr_payload');
      expect(result.outcome, equals(CheckInOutcome.denied));
      expect(result.message, contains('expired'));
    });

    test('Generic network error maps to error outcome', () async {
      when(() => mockFunctions.invoke(
        'recordAttendance',
        body: any(named: 'body'),
      )).thenThrow(Exception('SocketException: Connection refused'));

      final result = await repository.recordCheckIn('network_err_payload');
      expect(result.outcome, equals(CheckInOutcome.error));
      expect(result.message, equals('Unable to reach Supabase.'));
    });
  });
}
