import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_pecha/features/timer/presentation/utils/timer_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late TimerAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = TimerAnalytics(service);
  });

  test('timerStarted carries the preset, its kind and length in seconds', () {
    analytics.timerStarted(
      presetId: 't1',
      kind: TimerKind.preset,
      durationSeconds: 600,
    );

    expect(service.eventNames, [AnalyticsEvents.timerStarted]);
    expect(service.events.single.properties, {
      'preset_id': 't1',
      'timer_kind': 'preset',
      'duration_s': 600,
      'has_ambient_sound': false,
    });
  });

  test('timerStarted carries the background sound when there is one', () {
    analytics.timerStarted(
      presetId: 't1',
      kind: TimerKind.custom,
      durationSeconds: 600,
      ambientSoundId: 'rain',
    );

    expect(service.events.single.properties, {
      'preset_id': 't1',
      'timer_kind': 'custom',
      'duration_s': 600,
      'has_ambient_sound': true,
      'ambient_sound_id': 'rain',
    });
  });

  test('an empty sound id counts as no sound', () {
    analytics.timerStarted(
      presetId: 't1',
      kind: TimerKind.preset,
      durationSeconds: 600,
      ambientSoundId: '',
    );

    expect(service.events.single.properties['has_ambient_sound'], false);
    expect(
      service.events.single.properties.containsKey('ambient_sound_id'),
      isFalse,
    );
  });

  test('timerCompleted carries the pause count and backgrounding', () {
    analytics.timerCompleted(
      presetId: 't1',
      kind: TimerKind.custom,
      durationSeconds: 600,
      wasBackgrounded: true,
      pauseCount: 2,
    );

    expect(service.eventNames, [AnalyticsEvents.timerCompleted]);
    expect(service.events.single.properties, {
      'preset_id': 't1',
      'timer_kind': 'custom',
      'duration_s': 600,
      'was_backgrounded': true,
      'pause_count': 2,
      'has_ambient_sound': false,
    });
  });

  test('timerDiscarded says whether it was Finish or Discard', () {
    analytics.timerDiscarded(
      presetId: 't1',
      kind: TimerKind.routine,
      action: TimerEndAction.discard,
      elapsedSeconds: 90,
      pctComplete: 15,
    );

    expect(service.eventNames, [AnalyticsEvents.timerDiscarded]);
    expect(service.events.single.properties, {
      'preset_id': 't1',
      'timer_kind': 'routine',
      'action': 'discard',
      'elapsed_s': 90,
      'pct_complete': 15,
    });
  });

  test('custom timers have create, update and delete events', () {
    analytics.timerCreated(
      presetId: 't2',
      durationSeconds: 300,
      ambientSoundId: 'rain',
    );
    analytics.timerUpdated(presetId: 't2', durationSeconds: 420);
    analytics.timerDeleted(presetId: 't2');

    expect(service.eventNames, [
      AnalyticsEvents.timerCreated,
      AnalyticsEvents.timerUpdated,
      AnalyticsEvents.timerDeleted,
    ]);
    expect(service.events[0].properties, {
      'preset_id': 't2',
      'duration_s': 300,
      'has_ambient_sound': true,
      'ambient_sound_id': 'rain',
    });
    expect(service.events[1].properties, {
      'preset_id': 't2',
      'duration_s': 420,
      'has_ambient_sound': false,
    });
    expect(service.events.last.properties, {'preset_id': 't2'});
  });

  test('the timer kind comes from the timer', () {
    PresetTimer timer({required String id, required String type}) =>
        PresetTimer(id: id, name: 'T', durationMs: 1000, type: type);

    expect(
      TimerKind.of(timer(id: 'p', type: kPresetTimerTypePreset)),
      TimerKind.preset,
    );
    expect(
      TimerKind.of(timer(id: 'u', type: kPresetTimerTypeUserCreated)),
      TimerKind.custom,
    );
    expect(
      TimerKind.of(timer(id: '', type: kPresetTimerTypePreset)),
      TimerKind.routine,
    );
  });
}
