/// DI environment names used with `@Environment(...)`.
abstract final class Env {
  /// Mock data sources backed by bundled fixtures. No network, no secrets.
  static const String mock = 'mock';

  /// Real API data sources.
  static const String api = 'api';
}

/// Runtime configuration supplied via `--dart-define` (never hard-coded).
abstract final class AppConfig {
  /// Base URL of the REST API, e.g. `--dart-define=API_BASE_URL=https://...`.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// DI environment to boot with; defaults to [Env.mock] so a fresh clone runs.
  static const String diEnvironment = String.fromEnvironment(
    'DI_ENV',
    defaultValue: Env.mock,
  );
}
