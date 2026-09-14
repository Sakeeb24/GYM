// Environment configuration via --dart-define (never ship a .env asset —
// see audit anti-pattern A17). Example:
//   flutter run --dart-define=ENV=dev --dart-define=SUPABASE_URL=... \
//     --dart-define=SUPABASE_ANON_KEY=... --dart-define=APP_NAME=LiftFlow
class Env {
  Env._();

  static const String environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qwnxbdqzmxyukrbeqrcj.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bnhiZHF6bXh5dWtyYmVxcmNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5ODEwODQsImV4cCI6MjEwMzU1NzA4NH0.mxRoJKPP3kw2j0ycCX7BBuWsPCZFZ25ALUWRSg_AQoQ',
  );
  static const String appName = String.fromEnvironment('APP_NAME', defaultValue: 'LiftFlow');

  static bool get isDev => environment == 'dev';
  static bool get isStaging => environment == 'staging';
  static bool get isProduction => environment == 'production';

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define.',
      );
    }
  }
}
