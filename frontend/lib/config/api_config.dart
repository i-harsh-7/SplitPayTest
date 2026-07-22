/// Centralized API configuration.
///
/// The base URL can be overridden at build/run time without touching source:
///   flutter run --dart-define=API_BASE_URL=https://staging.example.com/api/v1
///   flutter build apk --dart-define=API_BASE_URL=https://api.splitpay.com/api/v1
///
/// When no override is provided it falls back to the production endpoint.
class ApiConfig {
  ApiConfig._();

  /// Root API base URL (includes the version segment).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://splitpaybackend-production.up.railway.app/api/v1',
  );

  /// Default network timeout for most requests.
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Longer timeout for heavy operations such as bill image upload/parsing.
  static const Duration uploadTimeout = Duration(seconds: 45);

  /// Builds a fully-qualified endpoint URI from a [path].
  ///
  /// [path] may be given with or without a leading slash.
  static Uri uri(String path, {Map<String, dynamic>? queryParameters}) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(
      queryParameters: queryParameters,
    );
  }
}
