import 'package:flutter_pecha/core/storage/server_switch_cleanup.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const boxes = ['text_content_cache', 'mala_counts', 'timers_local_data'];

  late List<String> deletedBoxes;
  late int pushResets;
  late int reminderCancels;

  ServerSwitchCleanupImpl cleanup({
    String server = 'production',
    Set<String> failingBoxes = const {},
    bool pushFails = false,
    bool remindersFail = false,
  }) => ServerSwitchCleanupImpl(
    server: server,
    serverBoxes: boxes,
    deleteBox: (box) async {
      if (failingBoxes.contains(box)) throw Exception('locked');
      deletedBoxes.add(box);
    },
    resetPushToken: () async {
      if (pushFails) throw Exception('offline');
      pushResets++;
    },
    cancelScheduledNotifications: () async {
      if (remindersFail) throw Exception('plugin');
      reminderCancels++;
    },
  );

  /// Account and server data, as a signed-in phone holds it.
  const serverData = <String, Object>{
    StorageKeys.userData: '{"id":"u1"}',
    StorageKeys.currentUserId: 'u1',
    StorageKeys.pushDeviceServerId: 'device-on-old-server',
    StorageKeys.fcmToken: 'fcm',
    StorageKeys.readerSettingsOwner: 'u1',
    StorageKeys.readerSettingsSynced: '{}',
    StorageKeys.connectLastSpaceId: 'space-1',
    StorageKeys.streakCount: 4,
    '${StorageKeys.malaLastUsedPresetPrefix}u1': 'preset-1',
    '${StorageKeys.malaAccumulationSelectionPrefix}u1': 'acc-1',
  };

  /// Settings of the device, which no server owns.
  const deviceSettings = <String, Object>{
    StorageKeys.themeMode: 'dark',
    StorageKeys.preferredLanguage: 'bo',
    StorageKeys.readerFonts: '{}',
    StorageKeys.malaSoundEnabled: false,
    StorageKeys.notificationMasterEnabled: true,
    StorageKeys.lastSignInMethod: 'google',
    'practice_recent_searches': <String>['heart sutra'],
  };

  setUp(() {
    deletedBoxes = [];
    pushResets = 0;
    reminderCancels = 0;
  });

  Future<SharedPreferences> prefsWith(String? lastServer) async {
    SharedPreferences.setMockInitialValues({
      ...serverData,
      ...deviceSettings,
      if (lastServer != null) ServerSwitchCleanupImpl.lastServerKey: lastServer,
    });
    return SharedPreferences.getInstance();
  }

  void expectNothingRemoved(SharedPreferences prefs) {
    for (final key in serverData.keys) {
      expect(prefs.containsKey(key), isTrue, reason: key);
    }
    expect(deletedBoxes, isEmpty);
    expect(pushResets, 0);
    expect(reminderCancels, 0);
  }

  test('the same server as last time removes nothing', () async {
    final prefs = await prefsWith('production');

    expect(await cleanup().run(), isFalse);

    expectNothingRemoved(prefs);
  });

  test('with no server recorded yet, it only records this one', () async {
    // A fresh install, or the first launch of a build with this check.
    final prefs = await prefsWith(null);

    expect(await cleanup().run(), isFalse);

    expectNothingRemoved(prefs);
    expect(prefs.getString(ServerSwitchCleanupImpl.lastServerKey), 'production');
  });

  group('another server than last time', () {
    test('removes the account and server data, keeps device settings', () async {
      // Ran the testing build, now the App Store (prod) one.
      final prefs = await prefsWith('staging');

      expect(await cleanup().run(), isTrue);

      for (final key in serverData.keys) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
      for (final entry in deviceSettings.entries) {
        expect(prefs.get(entry.key), entry.value, reason: entry.key);
      }
      expect(deletedBoxes, boxes);
      expect(pushResets, 1);
      expect(reminderCancels, 1);
      expect(
        prefs.getString(ServerSwitchCleanupImpl.lastServerKey),
        'production',
      );
    });

    test('runs once: the next launch on that server removes nothing', () async {
      await prefsWith('staging');
      await cleanup().run();
      deletedBoxes.clear();
      pushResets = 0;
      reminderCancels = 0;

      expect(await cleanup().run(), isFalse);

      expect(deletedBoxes, isEmpty);
    });

    group('with a box it cannot remove', () {
      /// What the person saved after the switch, signed in on this server.
      const newServerData = <String, Object>{
        StorageKeys.userData: '{"id":"u2"}',
        StorageKeys.currentUserId: 'u2',
        StorageKeys.pushDeviceServerId: 'device-on-new-server',
      };

      Future<SharedPreferences> afterAFailedSwitch() async {
        final prefs = await prefsWith('staging');
        expect(await cleanup(failingBoxes: {'mala_counts'}).run(), isTrue);
        return prefs;
      }

      Future<void> useTheApp(SharedPreferences prefs) async {
        for (final entry in newServerData.entries) {
          await prefs.setString(entry.key, entry.value as String);
        }
        deletedBoxes.clear();
        pushResets = 0;
        reminderCancels = 0;
      }

      void expectNewServerDataKept(SharedPreferences prefs) {
        for (final entry in newServerData.entries) {
          expect(prefs.get(entry.key), entry.value, reason: entry.key);
        }
        expect(pushResets, 0);
        expect(reminderCancels, 0);
      }

      test('still records this server, and lists the box', () async {
        final prefs = await afterAFailedSwitch();

        // The others still go.
        expect(deletedBoxes, ['text_content_cache', 'timers_local_data']);
        expect(
          prefs.getString(ServerSwitchCleanupImpl.lastServerKey),
          'production',
        );
        expect(prefs.getStringList(ServerSwitchCleanupImpl.leftoverBoxesKey), [
          'mala_counts',
        ]);
      });

      test('the next launch removes only that box', () async {
        final prefs = await afterAFailedSwitch();
        await useTheApp(prefs);

        expect(await cleanup().run(), isFalse);

        expect(deletedBoxes, ['mala_counts']);
        expectNewServerDataKept(prefs);
        expect(
          prefs.containsKey(ServerSwitchCleanupImpl.leftoverBoxesKey),
          isFalse,
        );

        // Nothing is left to retry.
        deletedBoxes.clear();
        expect(await cleanup().run(), isFalse);
        expect(deletedBoxes, isEmpty);
      });

      test('a box that never goes is retried alone on each launch', () async {
        final prefs = await afterAFailedSwitch();
        await useTheApp(prefs);

        for (var launch = 0; launch < 2; launch++) {
          expect(await cleanup(failingBoxes: {'mala_counts'}).run(), isFalse);
        }

        expect(deletedBoxes, isEmpty);
        expectNewServerDataKept(prefs);
        expect(prefs.getStringList(ServerSwitchCleanupImpl.leftoverBoxesKey), [
          'mala_counts',
        ]);
      });

      test('a switch to a third server starts over with every box', () async {
        final prefs = await afterAFailedSwitch();
        await useTheApp(prefs);

        expect(await cleanup(server: 'development').run(), isTrue);

        expect(deletedBoxes, boxes);
        expect(
          prefs.containsKey(ServerSwitchCleanupImpl.leftoverBoxesKey),
          isFalse,
        );
        expect(
          prefs.getString(ServerSwitchCleanupImpl.lastServerKey),
          'development',
        );
      });
    });

    test('a push or reminder failure does not hold it back', () async {
      final prefs = await prefsWith('staging');

      expect(
        await cleanup(pushFails: true, remindersFail: true).run(),
        isTrue,
      );

      expect(deletedBoxes, boxes);
      expect(
        prefs.getString(ServerSwitchCleanupImpl.lastServerKey),
        'production',
      );
    });
  });
}
