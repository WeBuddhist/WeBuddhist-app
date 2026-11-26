import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';

/// The speeds offered for the mantra marquee, slowest first.
const List<double> kMalaMantraSpeedPresets = [0.5, 0.75, 1.0, 1.25, 1.5];
const double kMalaMantraSpeedDefault = 1.0;

class MalaSettingsState {
  const MalaSettingsState({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.leftHanded = false,
    this.playAnimation = true,
    this.mantraSpeed = kMalaMantraSpeedDefault,
  });

  final bool soundEnabled;
  final bool vibrationEnabled;

  /// Counter sits on the right (thumb-side for a left hand) when true.
  final bool leftHanded;

  /// Whether the mantra lines scroll. When false they stand still.
  final bool playAnimation;

  /// Marquee speed multiplier, always one of [kMalaMantraSpeedPresets].
  final double mantraSpeed;

  MalaSettingsState copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? leftHanded,
    bool? playAnimation,
    double? mantraSpeed,
  }) => MalaSettingsState(
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    leftHanded: leftHanded ?? this.leftHanded,
    playAnimation: playAnimation ?? this.playAnimation,
    mantraSpeed: mantraSpeed ?? this.mantraSpeed,
  );
}

/// The preset closest to [speed], so a value saved by an older build (the
/// slider allowed anything from 0.5x to 2x) lands on a chip.
double snapMalaMantraSpeed(double speed) {
  var best = kMalaMantraSpeedPresets.first;
  for (final preset in kMalaMantraSpeedPresets) {
    if ((preset - speed).abs() < (best - speed).abs()) best = preset;
  }
  return best;
}

class MalaSettingsNotifier extends StateNotifier<MalaSettingsState> {
  MalaSettingsNotifier({MalaAnalytics? analytics})
    : _analytics = analytics,
      super(const MalaSettingsState()) {
    _load();
  }

  final MalaAnalytics? _analytics;

  void _track(MalaSetting setting, Object value) =>
      _analytics?.settingChanged(setting: setting, value: value);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = MalaSettingsState(
      soundEnabled: prefs.getBool(StorageKeys.malaSoundEnabled) ?? true,
      vibrationEnabled: prefs.getBool(StorageKeys.malaVibrationEnabled) ?? true,
      leftHanded: prefs.getBool(StorageKeys.malaLeftHanded) ?? false,
      playAnimation: prefs.getBool(StorageKeys.malaPlayAnimation) ?? true,
      mantraSpeed: snapMalaMantraSpeed(
        prefs.getDouble(StorageKeys.malaMantraSpeed) ?? kMalaMantraSpeedDefault,
      ),
    );
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _track(MalaSetting.sound, enabled);
    state = state.copyWith(soundEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.malaSoundEnabled, enabled);
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _track(MalaSetting.vibration, enabled);
    state = state.copyWith(vibrationEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.malaVibrationEnabled, enabled);
  }

  Future<void> setLeftHanded(bool leftHanded) async {
    _track(MalaSetting.leftHanded, leftHanded);
    state = state.copyWith(leftHanded: leftHanded);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.malaLeftHanded, leftHanded);
  }

  Future<void> setPlayAnimation(bool play) async {
    _track(MalaSetting.animation, play);
    state = state.copyWith(playAnimation: play);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.malaPlayAnimation, play);
  }

  Future<void> setMantraSpeed(double speed) async {
    final snapped = snapMalaMantraSpeed(speed);
    if (snapped != state.mantraSpeed) _track(MalaSetting.speed, snapped);
    state = state.copyWith(mantraSpeed: snapped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(StorageKeys.malaMantraSpeed, snapped);
  }
}

final malaSettingsProvider =
    StateNotifierProvider<MalaSettingsNotifier, MalaSettingsState>((ref) {
      return MalaSettingsNotifier(
        analytics: ref.read(malaAnalyticsProvider),
      );
    });
