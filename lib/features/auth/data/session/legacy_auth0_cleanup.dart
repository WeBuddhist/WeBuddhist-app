import 'dart:convert';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sign-in moved from Auth0 to Firebase, and the backend's own tokens became
/// the session. A phone updated from an Auth0 build still holds an Auth0
/// session this build cannot use, so it is removed once and the person signs
/// in again. Same as the web app's `clearLegacyAuth0Session`.
///
/// This is the only use of `auth0_flutter` left. Drop the package, this class
/// and the Auth0 entries in the Android manifest, `build.gradle.kts` and
/// `Info.plist` once builds older than the switch are no longer supported.
abstract class LegacyAuth0Cleanup {
  /// Returns true when an Auth0 session was found and removed. Never throws.
  Future<bool> run();
}

class LegacyAuth0CleanupImpl implements LegacyAuth0Cleanup {
  LegacyAuth0CleanupImpl({
    Future<void> Function(String domain, String clientId)? clearAuth0Credentials,
  }) : _clearAuth0Credentials =
           clearAuth0Credentials ?? _clearWithCredentialsManager;

  /// Set once the cleanup has run, so it never runs again.
  static const doneKey = 'legacy_auth0_session_cleared';

  /// Where Auth0 builds cached the tenant config from `/props`. Present on
  /// any phone that ever opened one online, so it also tells an update from a
  /// fresh install.
  static const cachedDomainKey = 'auth0_cfg_domain';
  static const cachedClientIdKey = 'auth0_cfg_client_id';
  static const cachedAudienceKey = 'auth0_cfg_audience';

  final Future<void> Function(String domain, String clientId)
  _clearAuth0Credentials;
  final _logger = AppLogger('LegacyAuth0Cleanup');

  @override
  Future<bool> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(doneKey) == true) return false;

      final domain = prefs.getString(cachedDomainKey);
      final clientId = prefs.getString(cachedClientIdKey);
      final hadAuth0 = domain != null && clientId != null;
      if (hadAuth0) {
        // Local only: clears the Keychain / encrypted storage entry. It does
        // not call Auth0, so it works offline and after the tenant is gone.
        await _clearAuth0Credentials(domain, clientId);
        await _rememberLocalUserId(prefs);
        // Markers of the signed-in Auth0 account.
        await prefs.remove(StorageKeys.currentUserId);
        await prefs.remove(StorageKeys.userData);
        await prefs.remove(cachedDomainKey);
        await prefs.remove(cachedClientIdKey);
        await prefs.remove(cachedAudienceKey);
        _logger.info('Removed the Auth0 session left by an earlier build');
      }
      await prefs.setBool(doneKey, true);
      return hadAuth0;
    } catch (e) {
      // Not marked done, so the next launch tries again.
      _logger.warning('Could not remove the earlier Auth0 session: $e');
      return false;
    }
  }

  /// Local data is keyed by the user id, which was the Auth0 subject
  /// (`google-oauth2|…`) and would now be the backend user id. Counts, timer
  /// stops and plan actions not yet sent to the server sit under the old one,
  /// and would never be found again. So the old id is remembered beside the
  /// account's backend id (from the cached profile), and `AuthNotifier` goes
  /// on using it when that same account signs back in.
  Future<void> _rememberLocalUserId(SharedPreferences prefs) async {
    final localUserId = prefs.getString(StorageKeys.currentUserId);
    if (localUserId == null || localUserId.isEmpty) return;
    await _rememberSignInMethod(prefs, localUserId);
    final backendUserId = _cachedProfileId(prefs);
    if (backendUserId == null) {
      // Cached before profiles carried an id. Without it a later sign-in
      // cannot be matched to this account, so its local data stays put.
      _logger.warning('No backend id cached for the Auth0 account');
      return;
    }
    await prefs.setString(StorageKeys.legacyAuth0UserId, localUserId);
    await prefs.setString(StorageKeys.legacyAuth0BackendUserId, backendUserId);
  }

  /// Everyone updating has to sign in again, and someone who picks another
  /// method than before gets a new, empty account. The Auth0 subject says
  /// which one they used (`google-oauth2|…`, `apple|…`, `sms|…`), so the
  /// sign-in buttons can mark it "Last used".
  Future<void> _rememberSignInMethod(
    SharedPreferences prefs,
    String auth0Subject,
  ) async {
    final method = switch (auth0Subject.split('|').first) {
      'google-oauth2' => 'google',
      'apple' => 'apple',
      'sms' => 'phone',
      _ => null,
    };
    if (method == null) return;
    await prefs.setString(StorageKeys.lastSignInMethod, method);
  }

  String? _cachedProfileId(SharedPreferences prefs) {
    try {
      final stored = prefs.getString(StorageKeys.userData);
      if (stored == null) return null;
      final profile = jsonDecode(stored);
      final id = profile is Map ? profile['id']?.toString().trim() : null;
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _clearWithCredentialsManager(
    String domain,
    String clientId,
  ) async {
    await Auth0(domain, clientId).credentialsManager.clearCredentials();
  }
}
