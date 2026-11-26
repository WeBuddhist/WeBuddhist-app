import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which kind of timer ran, carried as `timer_kind`.
enum TimerKind {
  /// A stock preset.
  preset,

  /// A timer the user made.
  custom,

  /// A practice-block timer saved as a bare duration, with no timer behind it.
  routine;

  static TimerKind of(PresetTimer timer) {
    if (timer.id.isEmpty) return TimerKind.routine;
    return timer.isUserCreated ? TimerKind.custom : TimerKind.preset;
  }

  String get key => name;
}

/// How a session ended before the bell, carried on `timer_discarded` as
/// `action`.
enum TimerEndAction {
  finish,
  discard;

  String get key => name;
}

/// Product analytics for the meditation timer: one method per tracked action,
/// so the event names and their property keys live in one place. Every call
/// fires and forgets; callers fire once the session really changed state.
class TimerAnalytics {
  const TimerAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// The pre-roll countdown ran out and the main timer is running.
  /// [ambientSoundId] is the background sound set on the timer, if any.
  void timerStarted({
    required String presetId,
    required TimerKind kind,
    required int durationSeconds,
    String? ambientSoundId,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.timerStarted, {
      AnalyticsProperties.presetId: presetId,
      AnalyticsProperties.timerKind: kind.key,
      AnalyticsProperties.durationSeconds: durationSeconds,
      ..._soundProperties(ambientSoundId),
    });
  }

  /// The session reached zero and the completion bell rang.
  void timerCompleted({
    required String presetId,
    required TimerKind kind,
    required int durationSeconds,
    required bool wasBackgrounded,
    required int pauseCount,
    String? ambientSoundId,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.timerCompleted, {
      AnalyticsProperties.presetId: presetId,
      AnalyticsProperties.timerKind: kind.key,
      AnalyticsProperties.durationSeconds: durationSeconds,
      AnalyticsProperties.wasBackgrounded: wasBackgrounded,
      AnalyticsProperties.pauseCount: pauseCount,
      ..._soundProperties(ambientSoundId),
    });
  }

  /// The user left the session before the bell, by Finish or Discard
  /// ([action]). [pctComplete] is 0-100.
  void timerDiscarded({
    required String presetId,
    required TimerKind kind,
    required TimerEndAction action,
    required int elapsedSeconds,
    required int pctComplete,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.timerDiscarded, {
      AnalyticsProperties.presetId: presetId,
      AnalyticsProperties.timerKind: kind.key,
      AnalyticsProperties.action: action.key,
      AnalyticsProperties.elapsedSeconds: elapsedSeconds,
      AnalyticsProperties.pctComplete: pctComplete,
    });
  }

  /// The server saved a new custom timer, with the background sound picked
  /// for it, if any.
  void timerCreated({
    required String presetId,
    required int durationSeconds,
    String? ambientSoundId,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.timerCreated, {
      AnalyticsProperties.presetId: presetId,
      AnalyticsProperties.durationSeconds: durationSeconds,
      ..._soundProperties(ambientSoundId),
    });
  }

  /// The server saved changes to a custom timer.
  void timerUpdated({
    required String presetId,
    required int durationSeconds,
    String? ambientSoundId,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.timerUpdated, {
      AnalyticsProperties.presetId: presetId,
      AnalyticsProperties.durationSeconds: durationSeconds,
      ..._soundProperties(ambientSoundId),
    });
  }

  /// The server deleted a custom timer.
  void timerDeleted({required String presetId}) {
    _analytics.trackInBackground(AnalyticsEvents.timerDeleted, {
      AnalyticsProperties.presetId: presetId,
    });
  }

  /// `has_ambient_sound` always, so sessions with and without sound split
  /// cleanly; `ambient_sound_id` only when there is one. An empty id means
  /// no sound.
  static Map<String, Object> _soundProperties(String? ambientSoundId) {
    final id = (ambientSoundId == null || ambientSoundId.isEmpty)
        ? null
        : ambientSoundId;
    return {
      AnalyticsProperties.hasAmbientSound: id != null,
      if (id != null) AnalyticsProperties.ambientSoundId: id,
    };
  }
}

final timerAnalyticsProvider = Provider<TimerAnalytics>((ref) {
  return TimerAnalytics(ref.watch(analyticsServiceProvider));
});
