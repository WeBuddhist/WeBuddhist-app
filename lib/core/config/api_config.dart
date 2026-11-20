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

  /// v2 mantra routes: `/{id}/images` lists a mantra's deity images.
  static const String mantrasV2Path = '$v2Prefix/mantras';

  /// v2 bead skins (`GET /mala-skins`).
  static const String malaSkinsV2Path = '$v2Prefix/mala-skins';

  /// v2 chat: the rooms inbox and mark-read, where unread is counted per
  /// message type (`unread: {"TEXT": n, "PRAYER": n}`).
  static const String chatV2Path = '$v2Prefix/chat';

  /// v2 per-user mantra routes: `/{id}/appearance` holds the user's deity
  /// image and bead skin for that mantra.
  static const String userMantrasV2Path = '$v2Prefix/users/me/mantras';

  /// v2 accumulation list. With `owner_type=platform` it is the preset
  /// catalogue, and with the token each row carries the user's `last_used_at`.
  static const String accumulationsV2Path = '$v2Prefix/accumulations';

  /// Full URL for a given path
  String urlFor(String path) => '$baseUrl$path';
}
