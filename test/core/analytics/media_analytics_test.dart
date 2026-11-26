import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/media_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late MediaAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = MediaAnalytics(service);
  });

  test('audioPlayed sums up one player', () {
    analytics.audioPlayed(
      surface: AudioSurface.plan,
      listened: const Duration(seconds: 95),
      speed: 1.25,
      repeat: false,
      completed: true,
      planId: 'p1',
      dayNumber: 3,
    );

    expect(service.eventNames, [AnalyticsEvents.audioPlayed]);
    expect(service.events.single.properties, {
      'surface': 'plan',
      'listened_s': 95,
      'speed': 1.25,
      'repeat': false,
      'completed': true,
      'plan_id': 'p1',
      'day_number': 3,
    });
  });

  test('a player that never played sends nothing', () {
    analytics.audioPlayed(
      surface: AudioSurface.reader,
      listened: Duration.zero,
      speed: 1,
      repeat: false,
      completed: false,
    );

    expect(service.events, isEmpty);
  });

  test('collection audio uses a snake_case surface', () {
    analytics.audioPlayed(
      surface: AudioSurface.recitationCollection,
      listened: const Duration(seconds: 10),
      speed: 1,
      repeat: true,
      completed: false,
      collectionId: 'c1',
    );

    expect(
      service.events.single.properties['surface'],
      'recitation_collection',
    );
  });

  test('audioSettingChanged names the setting and its value', () {
    analytics.audioSettingChanged(setting: AudioSetting.speed, value: 1.5);

    expect(service.events.single.name, AnalyticsEvents.audioSettingChanged);
    expect(service.events.single.properties, {
      'setting': 'speed',
      'value': 1.5,
    });
  });

  test('videoOpened sends the YouTube id, from a URL or a bare id', () {
    analytics.videoOpened(
      surface: VideoSurface.planShort,
      videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    analytics.videoOpened(
      surface: VideoSurface.accumulator,
      videoUrl: 'dQw4w9WgXcQ',
    );

    expect(service.events[0].properties, {
      'surface': 'plan_short',
      'video_id': 'dQw4w9WgXcQ',
    });
    expect(service.events[1].properties, {
      'surface': 'accumulator',
      'video_id': 'dQw4w9WgXcQ',
    });
  });
}
