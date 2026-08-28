// Environment configuration via --dart-define (never ship a .env asset —
// see audit anti-pattern A17). Example:
//   flutter run --dart-define=ENV=dev --dart-define=SUPABASE_URL=... \
//     --dart-define=SUPABASE_ANON_KEY=... --dart-define=APP_NAME=LiftFlow
class Env {
  Env._();

  static const String environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
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
