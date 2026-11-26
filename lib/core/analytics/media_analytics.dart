import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Where audio played, carried as `surface`.
enum AudioSurface {
  plan,
  reader,
  recitationCollection;

  String get key => switch (this) {
    AudioSurface.recitationCollection => 'recitation_collection',
    _ => name,
  };
}

/// An audio setting on the player bar, carried as `setting`.
enum AudioSetting { speed, repeat }

/// Where a video was opened, carried as `surface`.
enum VideoSurface {
  planShort,
  planSession,
  planText,
  reader,
  event,
  accumulator;

  String get key => switch (this) {
    VideoSurface.planShort => 'plan_short',
    VideoSurface.planSession => 'plan_session',
    VideoSurface.planText => 'plan_text',
    _ => name,
  };
}

/// Product analytics for audio and video. Audio is one summary per player,
/// sent when it closes, so play and pause taps don't each become an event.
class MediaAnalytics {
  const MediaAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// For widgets without a `ref`: reads the helper from the [context]'s scope.
  static MediaAnalytics of(BuildContext context) =>
      ProviderScope.containerOf(context, listen: false)
          .read(mediaAnalyticsProvider);

  /// A player closed after [listened] of actual playback. Nothing is sent
  /// when it never played.
  void audioPlayed({
    required AudioSurface surface,
    required Duration listened,
    required double speed,
    required bool repeat,
    required bool completed,
    String? planId,
    int? dayNumber,
    String? textId,
    String? collectionId,
    String? eventId,
  }) {
    if (listened <= Duration.zero) return;
    _analytics.trackInBackground(AnalyticsEvents.audioPlayed, {
      AnalyticsProperties.surface: surface.key,
      AnalyticsProperties.listenedS: listened.inSeconds,
      AnalyticsProperties.speed: speed,
      AnalyticsProperties.repeat: repeat,
      AnalyticsProperties.completed: completed,
      if (planId != null) AnalyticsProperties.planId: planId,
      if (dayNumber != null) AnalyticsProperties.dayNumber: dayNumber,
      if (textId != null) AnalyticsProperties.textId: textId,
      if (collectionId != null) AnalyticsProperties.collectionId: collectionId,
      if (eventId != null) AnalyticsProperties.eventId: eventId,
    });
  }

  /// Speed picked, or repeat turned on or off, on the player bar.
  void audioSettingChanged({
    required AudioSetting setting,
    required Object value,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.audioSettingChanged, {
      AnalyticsProperties.setting: setting.name,
      AnalyticsProperties.value: value,
    });
  }

  /// A video was opened full screen, or an inline one started playing.
  /// Opens only: the YouTube player doesn't report watch time reliably.
  void videoOpened({
    required VideoSurface surface,
    required String videoUrl,
    String? planId,
    String? eventId,
  }) {
    // A bare 11-character id is passed as is by some openers.
    final videoId =
        YoutubePlayer.convertUrlToId(videoUrl) ??
        (_bareVideoId.hasMatch(videoUrl.trim()) ? videoUrl.trim() : null);
    _analytics.trackInBackground(AnalyticsEvents.videoOpened, {
      AnalyticsProperties.surface: surface.key,
      if (videoId != null && videoId.isNotEmpty)
        AnalyticsProperties.videoId: videoId,
      if (planId != null) AnalyticsProperties.planId: planId,
      if (eventId != null) AnalyticsProperties.eventId: eventId,
    });
  }
}

final _bareVideoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

final mediaAnalyticsProvider = Provider<MediaAnalytics>((ref) {
  return MediaAnalytics(ref.watch(analyticsServiceProvider));
});
