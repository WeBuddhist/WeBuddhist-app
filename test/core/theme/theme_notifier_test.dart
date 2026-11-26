import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/theme/native_night_mode.dart';
import 'package:flutter_pecha/core/theme/theme_notifier.dart';
import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage implements LocalStorageService {
  _FakeStorage([Map<String, Object?>? values]) : values = {...?values};

  final Map<String, Object?> values;
  bool throwOnGet = false;

  @override
  Future<T?> get<T>(String key) async {
    if (throwOnGet) throw StateError('storage unavailable');
    return values[key] as T?;
  }

  @override
  Future<bool> set<T>(String key, T value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<void> setUserData(Map<String, dynamic> userData) async {}

  @override
  Future<Map<String, dynamic>?> getUserData() async => null;

  @override
  Future<void> clearUserData() async {}
}

void main() {
  test('ensureInitialized resolves to the saved theme mode', () async {
    final notifier = ThemeModeNotifier(
      localStorageService: _FakeStorage({
        StorageKeys.themeMode: ThemeMode.light.index,
      }),
    );
    expect(notifier.state, ThemeMode.system);

    await notifier.ensureInitialized();
    expect(notifier.state, ThemeMode.light);
    notifier.dispose();
  });

  test('stays on system with nothing saved', () async {
    final notifier = ThemeModeNotifier(localStorageService: _FakeStorage());
    await notifier.ensureInitialized();
    expect(notifier.state, ThemeMode.system);
    notifier.dispose();
  });

  test('ignores an out-of-range saved value', () async {
    final notifier = ThemeModeNotifier(
      localStorageService: _FakeStorage({StorageKeys.themeMode: 9}),
    );
    await notifier.ensureInitialized();
    expect(notifier.state, ThemeMode.system);
    notifier.dispose();
  });

  test('tells the platform the saved theme once loaded', () async {
    final applied = <ThemeMode>[];
    final notifier = ThemeModeNotifier(
      localStorageService: _FakeStorage({
        StorageKeys.themeMode: ThemeMode.light.index,
      }),
      applyNative: (mode) async => applied.add(mode),
    );
    await notifier.ensureInitialized();
    expect(applied, [ThemeMode.light]);
    notifier.dispose();
  });

  test('tells the platform system when nothing is saved', () async {
    final applied = <ThemeMode>[];
    final notifier = ThemeModeNotifier(
      localStorageService: _FakeStorage(),
      applyNative: (mode) async => applied.add(mode),
    );
    await notifier.ensureInitialized();
    expect(applied, [ThemeMode.system]);
    notifier.dispose();
  });

  test('tells the platform each theme the user picks', () async {
    final applied = <ThemeMode>[];
    final storage = _FakeStorage();
    final notifier = ThemeModeNotifier(
      localStorageService: storage,
      applyNative: (mode) async => applied.add(mode),
    );
    await notifier.ensureInitialized();
    applied.clear();

    await notifier.setTheme(ThemeMode.dark);
    notifier.toggleTheme(currentlyDark: true);
    await Future<void>.delayed(Duration.zero);

    expect(applied, [ThemeMode.dark, ThemeMode.light]);
    expect(storage.values[StorageKeys.themeMode], ThemeMode.light.index);
    notifier.dispose();
  });

  test('NativeNightMode maps each theme to its channel argument', () {
    expect(NativeNightMode.argumentFor(ThemeMode.light), 'light');
    expect(NativeNightMode.argumentFor(ThemeMode.dark), 'dark');
    expect(NativeNightMode.argumentFor(ThemeMode.system), 'system');
  });

  test('stays on system when storage cannot be read', () async {
    final storage = _FakeStorage()..throwOnGet = true;
    final notifier = ThemeModeNotifier(localStorageService: storage);
    await expectLater(notifier.ensureInitialized(), completes);
    expect(notifier.state, ThemeMode.system);
    notifier.dispose();
  });
}
