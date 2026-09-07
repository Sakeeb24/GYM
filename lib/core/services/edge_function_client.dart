// lib/core/services/edge_function_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/env.dart';
import 'supabase_client.dart';

/// Reusable HTTP client for invoking Supabase Edge Functions with standard
/// CORS-compliant headers (Content-Type, apikey, Authorization) without custom
/// client metadata headers (like x-client-info) that trigger preflight CORS rejections on the web.
class EdgeFunctionClient {
  EdgeFunctionClient._();

  /// Invokes an Edge Function via direct HTTP POST with standard CORS headers.
  static Future<Map<String, dynamic>> post(
    String functionName, {
    Map<String, dynamic> body = const {},
    String? customAuthToken,
  }) async {
    final url = Uri.parse('${Env.supabaseUrl}/functions/v1/$functionName');

    // Resolve Authorization token:
    // 1. Custom token if provided (e.g. for specific setup flows)
    // 2. Active user session access token if authenticated
    // 3. Fall back to public anon key for unauthenticated/anonymous functions
    String authToken = customAuthToken ?? '';
    if (authToken.isEmpty) {
      if (AppSupabase.isConfigured) {
        final session = AppSupabase.client.auth.currentSession;
        authToken = session?.accessToken ?? Env.supabaseAnonKey;
      } else {
        authToken = Env.supabaseAnonKey;
      }
    }

    final headers = {
      'Content-Type': 'application/json',
      'apikey': Env.supabaseAnonKey,
      'Authorization': 'Bearer $authToken',
    };

    try {
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = null;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return <String, dynamic>{'data': decoded};
      }

      final errorMsg = (decoded is Map && decoded['error'] is String)
          ? decoded['error'] as String
          : (decoded is Map && decoded['message'] is String)
              ? decoded['message'] as String
              : 'Service error (HTTP ${res.statusCode})';

      throw FunctionException(
        status: res.statusCode,
        details: errorMsg,
      );
    } catch (e) {
      if (e is FunctionException) rethrow;
      throw FunctionException(
        status: 0,
        details: 'Unable to reach $functionName service. Please try again.',
      );
    }
  }
}
