/// Runtime configuration.
///
/// Isolation rule #3: the app ships with the **anon key only**. The
/// service-role key never goes near the client — if you are tempted to put it
/// here, you want an Edge Function instead.
///
/// Values are injected at build time with --dart-define so no secrets are
/// committed:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
class Env {
  const Env._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
