import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/core/theme/native_night_mode.dart';
import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension that resolves the effective dark/light state of a ThemeMode.
///
/// Never compare `ThemeMode == ThemeMode.dark` directly — that misses
/// `ThemeMode.system` when the OS is in dark mode. Always use [isDark].
extension ThemeModeX on ThemeMode {
  /// Returns true if this mode resolves to a dark UI given [context]'s
  /// platform brightness. Handles [ThemeMode.system] correctly.
  bool isDark(BuildContext context) =>
      this == ThemeMode.dark ||
      (this == ThemeMode.system &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorageService _localStorageService;

  // Shared by every ensureInitialized() caller, so they all await the one
  // storage read.
  late final Future<void> _initFuture;

  /// Passes the theme on to the platform (see [NativeNightMode]); swapped in
  /// tests.
  final Future<void> Function(ThemeMode mode) _applyNative;

  ThemeModeNotifier({
    required LocalStorageService localStorageService,
    Future<void> Function(ThemeMode mode) applyNative = NativeNightMode.apply,
  }) : _localStorageService = localStorageService,
       _applyNative = applyNative,
       super(ThemeMode.system) {
    _initFuture = _loadThemeMode();
  }

  /// Completes once the saved theme mode has been read. main() awaits this
  /// before the first frame, so the launch splash already uses the saved
  /// theme rather than the phone's.
  Future<void> ensureInitialized() => _initFuture;

  // Load theme mode from local storage if available
  Future<void> _loadThemeMode() async {
    try {
      final themeIndex = await _localStorageService.get<int>(
        StorageKeys.themeMode,
      );
      if (themeIndex != null &&
          themeIndex >= 0 &&
          themeIndex < ThemeMode.values.length &&
          mounted) {
        state = ThemeMode.values[themeIndex];
      }
    } catch (_) {
      // Unreadable storage: keep following the system theme.
    }
    // Also covers a theme saved by an older version, before the platform
    // was told about it.
    if (mounted) unawaited(_applyNative(state));
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    unawaited(_applyNative(mode));
    await _localStorageService.set<int>(StorageKeys.themeMode, mode.index);
  }

  /// Toggles between light and dark. Pass [currentlyDark] from
  /// `themeMode.isDark(context)` so system mode is resolved correctly.
  void toggleTheme({required bool currentlyDark}) {
    setTheme(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Provider for managing theme mode (light/dark/system)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(
    localStorageService: ref.read(localStorageServiceProvider),
  ),
);
