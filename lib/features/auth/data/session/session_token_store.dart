import 'dart:convert';

import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/env.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The backend's own tokens: the app session since sign-in moved to Firebase.
class SessionTokens {
  const SessionTokens({required this.accessToken, required this.refreshToken});

  /// API bearer. A JWT whose `sub` is the backend user id.
  final String accessToken;

  /// Sent to `POST /auth/refresh-token` for a new [accessToken].
  final String refreshToken;

  SessionTokens withAccessToken(String accessToken) =>
      SessionTokens(accessToken: accessToken, refreshToken: refreshToken);
}

/// Where the session tokens are kept on the device.
abstract class SessionTokenStore {
  /// null when nothing is stored. Throws when the store could not be read,
  /// which says nothing about whether a session exists.
  Future<SessionTokens?> read();

  Future<void> write(SessionTokens tokens);

  Future<void> clear();
}

/// Keychain (iOS) / encrypted storage (Android), with the tokens held in
/// memory after the first read so requests do not hit the keystore each time.
///
/// The pair is kept as **one** value. Two separate entries could be left half
/// replaced by a failed or interrupted write: one account's access token
/// beside another's refresh token, which the next refresh would turn into a
/// silent switch of account.
///
/// The value also names the server that issued the session ([server]). Every
/// build is the same app, so one phone can run builds for different servers
/// in turn (dev, testing, prod), and the Keychain keeps the session even when
/// the app is deleted and installed again. Sent to another server, the tokens
/// are refused with a 500 the app cannot tell from an outage, so it would
/// look signed in while every request fails. A session from another server,
/// or one saved before sessions named their server, reads as no session and
/// is removed: the person signs in again.
class SecureSessionTokenStore implements SessionTokenStore {
  SecureSessionTokenStore({FlutterSecureStorage? storage, String? server})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Readable by background work (push handling) on a locked phone.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          ),
      _serverOverride = server;

  static const sessionKey = 'session_tokens';
  static const _accessField = 'access_token';
  static const _refreshField = 'refresh_token';
  static const _serverField = 'server';

  final FlutterSecureStorage _storage;
  final String? _serverOverride;
  final _logger = AppLogger('SessionTokenStore');

  /// The server this build talks to: the `ENVIRONMENT` of its `.env` file
  /// (`development`, `staging` or `production`). Not the URL, which can change
  /// for the same server without making its sessions invalid.
  String get server => _serverOverride ?? Env.environment;

  SessionTokens? _cached;
  bool _loaded = false;

  @override
  Future<SessionTokens?> read() async {
    if (_loaded) return _cached;
    final stored = _parse(await _storage.read(key: sessionKey));
    if (stored != null && stored[_serverField] != server) {
      await _removeForeign(stored[_serverField]);
      _cached = null;
    } else {
      _cached = _tokensFrom(stored);
    }
    _loaded = true;
    return _cached;
  }

  /// Best effort: if the delete fails, the session still reads as none here,
  /// and the next launch removes it.
  Future<void> _removeForeign(Object? storedServer) async {
    _logger.info(
      'Removing a session saved for '
      '${storedServer is String ? 'the "$storedServer" server' : 'an unnamed server'}; '
      'this build uses "$server"',
    );
    try {
      await _storage.delete(key: sessionKey);
    } catch (e) {
      _logger.warning('Could not remove the other server\'s session: $e');
    }
  }

  @override
  Future<void> write(SessionTokens tokens) async {
    // Memory first: the session is usable even if the keystore write fails,
    // and then only the next launch asks for a sign-in.
    _cached = tokens;
    _loaded = true;
    await _storage.write(
      key: sessionKey,
      value: jsonEncode({
        _accessField: tokens.accessToken,
        _refreshField: tokens.refreshToken,
        _serverField: server,
      }),
    );
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: sessionKey);
  }

  /// The stored value as a map, or null when nothing (readable) is stored.
  static Map<Object?, Object?>? _parse(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    try {
      final json = jsonDecode(stored);
      return json is Map ? json : null;
    } catch (_) {
      return null;
    }
  }

  /// null for nothing stored, or a value that is not a complete pair.
  static SessionTokens? _tokensFrom(Map<Object?, Object?>? json) {
    if (json == null) return null;
    final accessToken = json[_accessField];
    final refreshToken = json[_refreshField];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      return null;
    }
    return SessionTokens(accessToken: accessToken, refreshToken: refreshToken);
  }
}
