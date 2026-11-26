import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every build is the same app (`org.pecha.app`) and the entry file picks the
/// server: dev, testing or prod. One phone can therefore run builds for
/// different servers in turn, such as a developer switching entry files or a
/// tester updating from the TestFlight build to the App Store one.
///
/// What the app saved for one server means nothing to another: cached texts
/// and lists, the account's profile, counts and timer stops still waiting to
/// be sent, the push registration, reminders for that account's routine. So
/// when the server differs from the one the app last ran against, that data
/// is removed before anything reads it, and the app starts as after a logout.
///
/// Runs in `main()` before the local stores open. Device settings stay: theme,
/// language, reader and mala preferences, notification switches.
///
/// The login session is not handled here. It lives in the Keychain, which iOS
/// keeps when the app is deleted, while this marker is deleted with the app.
/// So the session names its own server (see `SecureSessionTokenStore`).
abstract class ServerSwitchCleanup {
  /// Returns true when the server changed and its data was removed. Never
  /// throws.
  Future<bool> run();
}

class ServerSwitchCleanupImpl implements ServerSwitchCleanup {
  ServerSwitchCleanupImpl({
    required this.server,
    required this.serverBoxes,
    Future<void> Function(String box)? deleteBox,
    Future<void> Function()? resetPushToken,
    Future<void> Function()? cancelScheduledNotifications,
  }) : _deleteBox = deleteBox ?? _deleteHiveBox,
       _resetPushToken = resetPushToken ?? _deleteFcmToken,
       _cancelScheduledNotifications =
           cancelScheduledNotifications ?? _cancelAllLocalNotifications;

  /// The server this build talks to: the `ENVIRONMENT` of its `.env` file.
  /// Not the URL, which can change for the same server (prod's library is
  /// due to move) without making its data wrong.
  final String server;

  /// Hive boxes filled from the server or holding work queued for it.
  final List<String> serverBoxes;

  final Future<void> Function(String box) _deleteBox;
  final Future<void> Function() _resetPushToken;
  final Future<void> Function() _cancelScheduledNotifications;
  final _logger = AppLogger('ServerSwitchCleanup');

  /// The server the app last ran against.
  static const lastServerKey = 'last_server_environment';

  /// Boxes of the previous server that a cleanup could not remove.
  static const leftoverBoxesKey = 'server_switch_leftover_boxes';

  /// Preferences that belong to the signed-in account or to the server.
  static const serverPreferenceKeys = <String>[
    StorageKeys.userData,
    StorageKeys.currentUserId,
    StorageKeys.userId,
    StorageKeys.profileData,
    StorageKeys.signInMethod,
    StorageKeys.accessToken,
    StorageKeys.refreshToken,
    StorageKeys.idToken,
    StorageKeys.onboardingStep,
    StorageKeys.onboardingData,
    StorageKeys.onboardingProfileSaved,
    // The registration made with the old server; a new one is made after
    // sign-in.
    StorageKeys.fcmToken,
    StorageKeys.pushDeviceServerId,
    // Cleared together, the device reads as never synced: an account with
    // saved settings wins, and one without receives the device's settings.
    // Left as they are, an account id that exists on both servers would
    // send the old server's values up as unsaved edits.
    StorageKeys.readerSettingsOwner,
    StorageKeys.readerSettingsSynced,
    StorageKeys.connectLastSpaceId,
    StorageKeys.connectOpenedSpaceIds,
    StorageKeys.lastProfileUpdate,
    StorageKeys.streakCount,
    StorageKeys.lastSyncTime,
  ];

  /// Preference families named after server ids (presets, accumulations).
  static const serverPreferencePrefixes = <String>[
    StorageKeys.malaAccumulationSelectionPrefix,
    StorageKeys.malaLastUsedPresetPrefix,
  ];

  @override
  Future<bool> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(lastServerKey);
      if (last == server) {
        await _retryLeftoverBoxes(prefs);
        return false;
      }
      if (last == null) {
        // A fresh install, which has nothing to remove, or the first launch
        // of a build with this check, which cannot know the previous server.
        await prefs.setString(lastServerKey, server);
        return false;
      }

      _logger.info('Server changed from "$last" to "$server"; removing its data');
      await _removePreferences(prefs);
      final leftover = await _removeBoxes(serverBoxes);
      // A stale push or reminder is less harm than a launch that never gets
      // past here, so these do not hold the marker back.
      await _bestEffort('reset the push token', _resetPushToken);
      await _bestEffort(
        'cancel scheduled reminders',
        _cancelScheduledNotifications,
      );
      // The marker is written even when a box is left. From here the person
      // signs in and saves data for this server, so a later launch must not
      // run the whole cleanup again: it would remove that data too. Only the
      // boxes still listed are retried.
      await _saveLeftoverBoxes(prefs, leftover);
      await prefs.setString(lastServerKey, server);
      return true;
    } catch (e) {
      _logger.warning('Could not remove the previous server\'s data: $e');
      return false;
    }
  }

  /// Removes the boxes an earlier cleanup could not, and nothing else. A box
  /// still listed holds the previous server's data, so it goes even though
  /// the app has used it since.
  Future<void> _retryLeftoverBoxes(SharedPreferences prefs) async {
    final leftover = prefs.getStringList(leftoverBoxesKey);
    if (leftover == null || leftover.isEmpty) return;
    await _saveLeftoverBoxes(prefs, await _removeBoxes(leftover));
  }

  /// Returns the boxes that could not be removed.
  Future<List<String>> _removeBoxes(List<String> boxes) async {
    final leftover = <String>[];
    for (final box in boxes) {
      final removed = await _bestEffort(
        'remove the "$box" box',
        () => _deleteBox(box),
      );
      if (!removed) leftover.add(box);
    }
    return leftover;
  }

  Future<void> _saveLeftoverBoxes(
    SharedPreferences prefs,
    List<String> leftover,
  ) async {
    if (leftover.isEmpty) {
      await prefs.remove(leftoverBoxesKey);
    } else {
      await prefs.setStringList(leftoverBoxesKey, leftover);
    }
  }

  Future<void> _removePreferences(SharedPreferences prefs) async {
    for (final key in serverPreferenceKeys) {
      await prefs.remove(key);
    }
    final prefixed = prefs.getKeys().where(
      (key) => serverPreferencePrefixes.any(key.startsWith),
    );
    for (final key in prefixed.toList()) {
      await prefs.remove(key);
    }
  }

  /// Returns whether [step] succeeded.
  Future<bool> _bestEffort(String what, Future<void> Function() step) async {
    try {
      await step();
      return true;
    } catch (e) {
      _logger.warning('Could not $what: $e');
      return false;
    }
  }

  static bool _hiveReady = false;

  static Future<void> _deleteHiveBox(String box) async {
    if (!_hiveReady) {
      await Hive.initFlutter();
      _hiveReady = true;
    }
    await Hive.deleteBoxFromDisk(box);
  }

  /// The old server still holds this phone's token and would keep sending
  /// it pushes; a deleted token reaches nobody. The app registers a new one
  /// after sign-in.
  static Future<void> _deleteFcmToken() async {
    if (Firebase.apps.isEmpty) return;
    await FirebaseMessaging.instance.deleteToken();
  }

  /// Same as a logout: reminders for the old account's routine and practices.
  static Future<void> _cancelAllLocalNotifications() =>
      FlutterLocalNotificationsPlugin().cancelAll();
}
