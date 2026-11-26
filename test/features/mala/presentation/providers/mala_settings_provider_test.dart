import 'package:flutter_pecha/features/mala/presentation/providers/mala_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('snapMalaMantraSpeed', () {
    test('keeps a preset as is', () {
      for (final preset in kMalaMantraSpeedPresets) {
        expect(snapMalaMantraSpeed(preset), preset);
      }
    });

    test('moves an old slider value to the nearest chip', () {
      expect(snapMalaMantraSpeed(2.0), 1.5);
      expect(snapMalaMantraSpeed(1.8), 1.5);
      expect(snapMalaMantraSpeed(0.9), 1.0);
      expect(snapMalaMantraSpeed(0.3), 0.5);
    });
  });

  test('loads a saved 2x speed as 1.5x and play animation on', () async {
    SharedPreferences.setMockInitialValues({'mala_mantra_speed': 2.0});
    final notifier = MalaSettingsNotifier();
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.mantraSpeed, 1.5);
    expect(notifier.state.playAnimation, isTrue);
    notifier.dispose();
  });

  test('saves play animation off', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = MalaSettingsNotifier();
    await Future<void>.delayed(Duration.zero);
    await notifier.setPlayAnimation(false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('mala_play_animation'), isFalse);
    expect(notifier.state.playAnimation, isFalse);
    notifier.dispose();
  });
}
