import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

final _logger = AppLogger('AppOpenAnalytics');

/// The names PostHog's SDKs used. Reports query them by name; keep them.
abstract final class AppLifecycleEvents {
  static const String installed = 'Application Installed';
  static const String updated = 'Application Updated';
  static const String opened = 'Application Opened';
  static const String backgrounded = 'Application Backgrounded';
}

/// Version name and build number of the running app.
@immutable
class AppBuildInfo {
  const AppBuildInfo({required this.version, required this.build});

  final String version;
  final String build;
}

/// What an install from before this tracking existed left behind.
///
/// [build] is null when the install is known only from other app data, so
/// the previous version cannot be told.
@immutable
class LegacyInstall {
  const LegacyInstall({this.version, this.build});

  final String? version;
  final String? build;
}

/// Key-value storage for the open tracking, kept apart from PostHog's own so
/// that PostHog reset() on logout does not touch it.
abstract class AppOpenStore {
  Future<String?> getString(String key);
  Future<bool?> getBool(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}

/// [SharedPreferencesAsync]: DataStore on Android and un-prefixed
/// UserDefaults keys on iOS, so the legacy `SharedPreferences.clear()` used
/// elsewhere in the app cannot wipe it either.
class SharedPreferencesAppOpenStore implements AppOpenStore {
  SharedPreferencesAppOpenStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> getString(String key) => _prefs.getString(key);

  @override
  Future<bool?> getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Sends Application Installed / Updated / Opened / Backgrounded only when
/// the app is actually shown, in place of PostHog's automatic lifecycle
/// events, which also fire for headless starts.
///
/// The UI counts as shown on the first [AppLifecycleState.resumed]. A headless
/// engine never gets one; an engine that started headless gets it when the
/// user opens the app, and that becomes the process's first open.
class AppOpenAnalytics with WidgetsBindingObserver {
  AppOpenAnalytics({
    required AppOpenStore store,
    required Future<void> Function(String event, Map<String, Object> props)
    capture,
    required Future<void> Function() onFirstOpen,
    Future<AppBuildInfo?> Function()? buildInfo,
  }) : _store = store,
       _capture = capture,
       _onFirstOpen = onFirstOpen,
       _buildInfo = buildInfo ?? _platformBuildInfo;

  @visibleForTesting
  static const String versionKey = 'webuddhist.analytics.last_open_version';
  @visibleForTesting
  static const String buildKey = 'webuddhist.analytics.last_open_build';
  @visibleForTesting
  static const String existingInstallKey =
      'webuddhist.analytics.existing_install';
  @visibleForTesting
  static const String migratedKey = 'webuddhist.analytics.install_migrated';

  final AppOpenStore _store;
  final Future<void> Function(String event, Map<String, Object> props) _capture;
  final Future<void> Function() _onFirstOpen;
  final Future<AppBuildInfo?> Function() _buildInfo;

  bool _hasOpened = false;
  bool _inBackground = false;
  Future<void> _queue = Future.value();

  /// Seeds the store for installs that predate this tracking, so they get
  /// Application Updated rather than Installed.
  ///
  /// Must run before PostHog setup on the first start of this version: from
  /// setup on, the SDK rewrites its stored version with the current one, and
  /// would make a fresh install that started headless look like an update.
  static Future<void> migrate({
    required AppOpenStore store,
    required Future<LegacyInstall?> Function() probe,
  }) async {
    try {
      if (await store.getBool(migratedKey) ?? false) return;
      if (await store.getString(buildKey) == null) {
        final LegacyInstall? legacy = await probe();
        final String? build = legacy?.build;
        if (build != null) {
          await store.setString(buildKey, build);
          final String? version = legacy?.version;
          if (version != null) await store.setString(versionKey, version);
        } else if (legacy != null) {
          await store.setBool(existingInstallKey, true);
        }
      }
      await store.setBool(migratedKey, true);
    } catch (e) {
      // Left unmarked so the next start tries again.
      _logger.warning('Install migration failed: $e');
    }
  }

  /// Starts listening, and counts an app that is already in the foreground.
  void attach([WidgetsBinding? binding]) {
    final WidgetsBinding b = binding ?? WidgetsBinding.instance;
    b.addObserver(this);
    final AppLifecycleState? state = b.lifecycleState;
    if (state != null) didChangeAppLifecycleState(state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(handleLifecycleState(state));
  }

  /// Handles one state change, after the previous one has finished.
  @visibleForTesting
  Future<void> handleLifecycleState(AppLifecycleState state) {
    return _queue = _queue.then((_) => _handle(state));
  }

  Future<void> _handle(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_hasOpened) {
          _hasOpened = true;
          _inBackground = false;
          await _firstOpen();
        } else if (_inBackground) {
          _inBackground = false;
          await _send(AppLifecycleEvents.opened, {'from_background': true});
        }
      case AppLifecycleState.paused:
        if (_hasOpened && !_inBackground) {
          _inBackground = true;
          await _send(AppLifecycleEvents.backgrounded, const {});
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _firstOpen() async {
    try {
      final AppBuildInfo? current = await _buildInfo();
      if (current != null) await _sendInstallOrUpdate(current);
      await _send(AppLifecycleEvents.opened, {
        'from_background': false,
        if (current != null) 'version': current.version,
        if (current != null) 'build': _buildValue(current.build),
      });
    } catch (e) {
      _logger.warning('Recording the app open failed: $e');
    } finally {
      await _onFirstOpen();
    }
  }

  Future<void> _sendInstallOrUpdate(AppBuildInfo current) async {
    final String? lastBuild = await _store.getString(buildKey);
    final String? lastVersion = await _store.getString(versionKey);
    final bool existingInstall =
        await _store.getBool(existingInstallKey) ?? false;

    final Map<String, Object> props = {};
    final String? event;
    if (lastBuild == null) {
      event =
          existingInstall
              ? AppLifecycleEvents.updated
              : AppLifecycleEvents.installed;
    } else if (lastBuild != current.build) {
      event = AppLifecycleEvents.updated;
      if (lastVersion != null) props['previous_version'] = lastVersion;
      props['previous_build'] = _buildValue(lastBuild);
    } else {
      event = null;
    }

    if (event != null) {
      props['version'] = current.version;
      props['build'] = _buildValue(current.build);
      await _send(event, props);
    }

    await _store.setString(versionKey, current.version);
    await _store.setString(buildKey, current.build);
    if (existingInstall) await _store.remove(existingInstallKey);
  }

  Future<void> _send(String event, Map<String, Object> props) async {
    try {
      await _capture(event, props);
    } catch (e) {
      _logger.warning('Capturing $event failed: $e');
    }
  }

  /// A numeric build goes out as a number, as both SDKs sent it.
  static Object _buildValue(String build) => int.tryParse(build) ?? build;

  static Future<AppBuildInfo?> _platformBuildInfo() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return AppBuildInfo(version: info.version, build: info.buildNumber);
    } catch (_) {
      return null;
    }
  }
}

/// Finds an install from before this tracking existed.
///
/// First choice is the version PostHog's own SDK stored: it is written on
/// every PostHog setup, so it is there exactly for devices that PostHog has
/// already counted as installed, and it gives previous_version and
/// previous_build. Its location: the `posthog-android-<token>` shared
/// preferences file on Android, `PHGVersionKey`/`PHGBuildKeyV2` in standard
/// UserDefaults on iOS. Neither survives an uninstall (Android backup is off),
/// and PostHog reset() leaves them alone.
///
/// Fallback: any key the app itself saved in SharedPreferences, for a device
/// whose PostHog file is missing or under another project token.
Future<LegacyInstall?> readLegacyInstall({required String posthogToken}) async {
  final LegacyInstall? fromPostHog = await _readPostHogStoredVersion(
    posthogToken,
  );
  if (fromPostHog != null) return fromPostHog;

  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getKeys().isNotEmpty) return const LegacyInstall();
  } catch (e) {
    _logger.warning('Reading app preferences for migration failed: $e');
  }
  return null;
}

Future<LegacyInstall?> _readPostHogStoredVersion(String token) async {
  final String? version;
  final String? build;
  if (Platform.isAndroid) {
    final prefs = SharedPreferencesAsync(
      options: SharedPreferencesAsyncAndroidOptions(
        backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
        originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
          fileName: 'posthog-android-$token',
        ),
      ),
    );
    version = await _tryRead(() => prefs.getString('version'));
    build =
        (await _tryRead(() => prefs.getInt('build')))?.toString() ??
        await _tryRead(() => prefs.getString('build'));
  } else if (Platform.isIOS) {
    final prefs = SharedPreferencesAsync();
    version = await _tryRead(() => prefs.getString('PHGVersionKey'));
    build =
        await _tryRead(() => prefs.getString('PHGBuildKeyV2')) ??
        await _tryRead(() => prefs.getString('PHGBuildKey'));
  } else {
    return null;
  }
  if (version == null && build == null) return null;
  return LegacyInstall(version: version, build: build);
}

Future<T?> _tryRead<T>(Future<T?> Function() read) async {
  try {
    return await read();
  } catch (_) {
    return null;
  }
}
