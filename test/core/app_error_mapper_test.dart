// test/core/app_error_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/core/utils/app_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppErrorMapper Tests', () {
    test('Maps Invalid API key to client key rejected message', () {
      final error = AuthApiException('Invalid API key', statusCode: '401');
      final msg = AppErrorMapper.toUserMessage(error);
      expect(msg, 'Supabase client key was rejected.');
    });

    test('Maps missing key state error to client key missing message', () {
      final error = StateError('SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define.');
      final msg = AppErrorMapper.toUserMessage(error);
      expect(msg, 'Supabase client key is missing.');
    });

    test('Maps network failure to unable to reach Supabase message', () {
      final error = Exception('Failed host lookup: qwnxbdqzmxyukrbeqrcj.supabase.co');
      final msg = AppErrorMapper.toUserMessage(error);
      expect(msg, 'Unable to reach Supabase.');
    });

    test('Maps FunctionException 409 to duplicate phone user-friendly message', () {
      final error = FunctionException(
        status: 409,
        details: {'error': 'This phone number is already registered. Please log in with your username and password.'},
      );

      final msg = AppErrorMapper.toUserMessage(error);
      expect(msg, 'This phone number is already registered. Please log in with your username and password.');
    });

    test('Maps FunctionException 409 without details to duplicate phone message', () {
      final error = FunctionException(
        status: 409,
      );

      final msg = AppErrorMapper.toUserMessage(error);
      expect(msg, 'This phone number is already registered. Please log in with your username and password.');
    });

    test('Maps PostgrestException duplicate phone constraint to user-friendly message', () {
      final error = PostgrestException(
        message: 'duplicate key value violates unique constraint "members_phone_key"',
        code: '23505',
      );

      final msg = AppErrorMapper.toUserMessage(error);
      expect(msg, 'This phone number is already registered. Please log in with your username and password.');
    });

    test('Maps PostgrestException duplicate username constraint to user-friendly message', () {
      final error = PostgrestException(
        message: 'duplicate key value violates unique constraint "profiles_username_key"',
        code: '23505',
      );

      final msg = AppErrorMapper.toUserMessage(error);
      expect(msg, 'This username is already taken. Please choose another username.');
    });

    test('Maps invalid login credentials to user-friendly message', () {
      final error = AuthException('Invalid login credentials');

      final msg = AppErrorMapper.toUserMessage(error);
      expect(msg, 'Invalid username or password. Please try again.');
    });
  });
}
