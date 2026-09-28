class ApiConfig {
  ApiConfig._();

  /// Override at build/run time with --dart-define=API_BASE_URL=http://10.0.2.2:8000
  /// (Android emulator), http://localhost:8000 (web/iOS simulator), or your LAN IP
  /// for a physical device.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const apiV1 = '$baseUrl/api/v1';

  static String get wsBaseUrl => baseUrl.replaceFirst('http', 'ws');
}
