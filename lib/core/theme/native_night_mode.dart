import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';

/// Hands the in-app theme to Android, which keeps it per app (Android 12+)
/// and draws the system launch screen in it on the next cold start. Without
/// this, a phone in dark mode shows a dark launch screen for an app set to
/// light. iOS draws its launch screen from the phone's setting and offers no
/// equivalent, so this is Android only.
class NativeNightMode {
  NativeNightMode._();

  static const MethodChannel _channel = MethodChannel(
    'org.pecha.app/app_theme',
  );

  /// The channel argument for [mode].
  static String argumentFor(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  /// Best effort: a failure only means the launch screen keeps following the
  /// phone, so it never surfaces.
  static Future<void> apply(ThemeMode mode) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setNightMode', <String, String>{
        'mode': argumentFor(mode),
      });
    } catch (_) {}
  }
}
