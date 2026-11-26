import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/reader/presentation/utils/reader_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late ReaderAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = ReaderAnalytics(service);
  });

  test('a reader setting change, with and without a value', () {
    analytics.settingChanged(setting: ReaderSetting.originalSize, value: 3);
    analytics.settingChanged(setting: ReaderSetting.font);

    expect(service.eventNames, [
      AnalyticsEvents.readerSettingChanged,
      AnalyticsEvents.readerSettingChanged,
    ]);
    expect(service.events[0].properties, {
      'setting': 'original_size',
      'value': 3,
    });
    expect(service.events[1].properties, {'setting': 'font'});
  });

  test('a live recitation visit sums up its following', () {
    analytics.recitationLiveFollowed(
      eventId: 'ev1',
      following: const Duration(minutes: 12, seconds: 5),
      pausedCount: 2,
      resumedCount: 1,
    );

    expect(service.events.single.name, AnalyticsEvents.recitationLiveFollowed);
    expect(service.events.single.properties, {
      'event_id': 'ev1',
      'following_s': 725,
      'paused_count': 2,
      'resumed_count': 1,
    });
  });
}
