// lib/core/services/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/env.dart';

/// Lazy, singleton Supabase client initialised from dart-define env.
/// The anon key is safe on the client; service-role NEVER lives in Flutter
/// (rule 7). RLS enforces tenant isolation at the DB layer.
class AppSupabase {
  AppSupabase._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    Env.validate();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: Env.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
