/// Which environment this build talks to. Set at build time:
///   flutter run --dart-define-from-file=env/dev.json
/// With no server configured the app runs in demo mode (simulated hikers).
class Env {
  static const name = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Text for the top banner. Production shows none.
  static String? get banner {
    if (!hasBackend) {
      return 'DEMO: other hikers are simulated. No server connected.';
    }
    return switch (name) {
      'prod' => null,
      'staging' => 'STAGING: test data only. Not for real emergencies.',
      _ => 'DEV build: local test server. Not for real emergencies.',
    };
  }
}
