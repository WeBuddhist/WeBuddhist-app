import 'package:flutter_pecha/env.dart';

/// API configuration for the app.
///
/// Provides centralized API configuration including base URLs,
/// timeouts, and other HTTP client settings.
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
  });

  /// Base URL for all API requests
  final String baseUrl;

  /// Timeout for establishing a connection
  final Duration connectTimeout;

  /// Timeout for receiving data
  final Duration receiveTimeout;

  /// Timeout for sending data
  final Duration sendTimeout;

  /// Current API config (from environment)
  static ApiConfig get current => ApiConfig(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: Env.apiTimeout,
    receiveTimeout: Env.apiTimeout,
    sendTimeout: Env.apiTimeout,
  );

  /// API endpoint paths
  static const String usersPath = '/users';
  static const String userInfoPath = '/users/info';
  static const String userMePath = '/users/me';
  static const String plansPath = '/plans';
  static const String tasksPath = '/tasks';

  /// Prefix for v2 paths on the main client. The base URL ends in `/api/v1`
  /// and Dio normalizes dot segments, so `'$v2Prefix/spaces'` is sent to
  /// `/api/v2/spaces` while interceptors still see a relative path to match
  /// against `ProtectedRoutes`.
  static const String v2Prefix = '/../v2';
  static const String spacesV2Path = '$v2Prefix/spaces';

  /// Full URL for a given path
  String urlFor(String path) => '$baseUrl$path';
}
