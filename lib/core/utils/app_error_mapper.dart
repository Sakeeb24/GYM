// lib/core/utils/app_error_mapper.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized error mapper converting technical exceptions (Postgres, HTTP, Supabase)
/// into user-friendly athletic error messages without exposing sensitive keys or stack traces.
class AppErrorMapper {
  AppErrorMapper._();

  static String toUserMessage(Object error) {
    final str = error.toString().toLowerCase();

    // Check for API key errors
    if (str.contains('invalid api key') || str.contains('api key') && (str.contains('invalid') || str.contains('rejected') || str.contains('unauthorized'))) {
      return 'Supabase client key was rejected.';
    }
    if (str.contains('key is missing') || str.contains('must be provided via --dart-define')) {
      return 'Supabase client key is missing.';
    }
    if (str.contains('socketexception') || str.contains('network') || str.contains('connection refused') || str.contains('failed host lookup') || str.contains('clientexception')) {
      return 'Unable to reach Supabase.';
    }

    // QR Activation specific mappings
    if (str.contains('expired')) {
      return 'This activation QR has expired. Ask the gym owner to generate a new one.';
    }
    if (str.contains('already been used') || str.contains('already used') || str.contains('already been consumed')) {
      return 'This activation QR has already been used. Ask the gym owner for a new QR code.';
    }
    if (str.contains('refreshed or canceled') || str.contains('revoked')) {
      return 'This activation QR has been refreshed or canceled. Ask the gym owner for a new QR code.';
    }
    if (str.contains('not valid for liftflow') || str.contains('malformed') || str.contains('invalid qr')) {
      return 'This QR code is not valid for LiftFlow.';
    }
    if (str.contains('another gym') || str.contains('does not belong to this gym')) {
      return 'This activation belongs to another gym.';
    }

    // Owner registration specific mappings
    if (str.contains('invalid setup code')) {
      return 'Invalid setup code. Please contact LiftFlow support.';
    }
    if (str.contains('owner setup is not configured')) {
      return 'Owner setup is not configured on this server. Please contact LiftFlow support.';
    }
    if (str.contains('gym slug') && (str.contains('already taken') || str.contains('taken'))) {
      return 'This gym URL handle is already taken. Please choose a different gym name or adjust the slug.';
    }
    if (str.contains('gym url handle') || str.contains('gym slug must be')) {
      return 'Gym slug must be 2\u201350 characters: lowercase letters, digits, and hyphens only.';
    }

    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid grant')) {
        return 'Invalid username or password. Please try again.';
      }
      if (msg.contains('user already registered') || msg.contains('already exists')) {
        return 'This phone number is already registered. Please log in with your username and password.';
      }
      if (msg.contains('sms_send_failed') || msg.contains('sms') || msg.contains('provider')) {
        return 'SMS delivery error: ${error.message}';
      }
      if (msg.contains('otp') || msg.contains('token')) {
        if (msg.contains('expired')) {
          return 'The verification code has expired. Please request a new code.';
        }
        return 'Invalid verification code. Please check and try again.';
      }
      if (msg.contains('rate limit') || msg.contains('too many requests')) {
        return 'Too many attempts. Please wait a minute before trying again.';
      }
      return error.message;
    }

    if (error is PostgrestException) {
      if (error.code == '23505') {
        if (error.message.contains('username')) {
          return 'This username is already taken. Please choose another username.';
        }
        if (error.message.contains('phone')) {
          return 'This phone number is already registered. Please log in with your username and password.';
        }
        return 'A record with these details already exists.';
      }
      if (error.code == '42501') {
        return 'Access denied: You do not have permission to perform this action.';
      }
      return 'Database operation failed. Please check your connection and retry.';
    }

    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        return details['error'] as String;
      }
      if (details is String) {
        if (details.contains('"error":')) {
          final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(details);
          if (match != null && match.group(1) != null) {
            return match.group(1)!;
          }
        }
        return details;
      }
      if (error.status == 409) {
        return 'This phone number is already registered. Please log in with your username and password.';
      }
      if (error.status == 410) {
        return 'This activation QR has expired or been used. Ask the gym owner for a new QR code.';
      }
      if (error.status == 400) {
        return 'Invalid request details. Please check your inputs.';
      }
      if (error.status == 403) {
        return 'Invalid setup code. Please contact LiftFlow support.';
      }
      if (error.status == 404) {
        return 'This QR code is not valid for LiftFlow.';
      }
    }

    if (str.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Clean up generic exception string prefixes
    String raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      raw = raw.substring(11);
    } else if (raw.startsWith('StateError: ')) {
      raw = raw.substring(12);
    }
    return raw;
  }
}
