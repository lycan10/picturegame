/// Central backend configuration.
class AppConfig {
  /// Base URL of the Hono backend. ALWAYS pass --dart-define=API_BASE_URL=…
  /// when building for anything other than the Android emulator.
  ///
  /// - Android emulator: http://10.0.2.2:8787 (default below)
  /// - iOS simulator / desktop: --dart-define=API_BASE_URL=http://localhost:8787
  /// - Physical device: --dart-define=API_BASE_URL=http://<your-lan-ip>:8787
  /// - Production: --dart-define=API_BASE_URL=https://picturegames-backend.<your-subdomain>.workers.dev
  ///
  /// Release builds refuse to start against a non-https URL (see main.dart)
  /// so a cleartext default can never ship to players.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    //defaultValue: 'http://192.168.1.169:8787',
    defaultValue: 'https://picturegames.edgebaas.workers.dev',
  );

  static const String apiV1 = '$baseUrl/api/v1';

  /// True when the configured base URL would send auth tokens over an
  /// unencrypted connection. Debug builds may do this deliberately (local
  /// development); release builds must not (enforced in main.dart).
  static bool get usesCleartext => !baseUrl.startsWith('https://');
}
