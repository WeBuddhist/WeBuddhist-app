import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_settings_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late MalaAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = MalaAnalytics(service);
  });

  test('a setting change names the setting in snake_case', () {
    analytics.settingChanged(setting: MalaSetting.leftHanded, value: true);

    expect(service.events.single.name, AnalyticsEvents.malaSettingChanged);
    expect(service.events.single.properties, {
      'setting': 'left_handed',
      'value': true,
    });
  });

  test('restoring the default image is sent as default', () {
    analytics.settingChanged(setting: MalaSetting.deityImage, presetId: 'm1');

    expect(service.events.single.properties, {
      'setting': 'deity_image',
      'value': 'default',
      'preset_id': 'm1',
    });
  });

  test('a count reset says personal or group', () {
    analytics.countReset(presetId: 'm1');
    analytics.countReset(presetId: 'm1', groupAccumulatorId: 'ga1');

    expect(service.eventNames, [
      AnalyticsEvents.malaCountReset,
      AnalyticsEvents.malaCountReset,
    ]);
    expect(service.events[0].properties, {
      'preset_id': 'm1',
      'mode': 'personal',
    });
    expect(service.events[1].properties, {
      'preset_id': 'm1',
      'mode': 'group',
      'group_accumulator_id': 'ga1',
    });
  });

  test('the settings notifier tracks user changes, not loading', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = MalaSettingsNotifier(analytics: analytics);
    await Future<void>.delayed(Duration.zero);
    expect(service.events, isEmpty);

    await notifier.setSoundEnabled(false);
    await notifier.setMantraSpeed(1.5);
    // Picking the current speed again is not a change.
    await notifier.setMantraSpeed(1.5);

    expect(
      service.events.map((e) => e.properties['setting']),
      ['sound', 'speed'],
    );
    expect(service.events.last.properties['value'], 1.5);
    notifier.dispose();
  });
}
