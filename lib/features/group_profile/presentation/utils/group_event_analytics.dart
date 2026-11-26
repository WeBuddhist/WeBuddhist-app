import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_event.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_link_utils.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_live_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What "enter the live event" opened, carried on `group_event_live_entered`.
enum GroupEventLiveTarget { series, plan, collection }

/// Whether an event has started, is on or is over, carried as `status`.
/// Decided the same way as the live player ([GroupEventLiveUtils]), so
/// analytics agrees with what the screen shows.
enum GroupEventStatus {
  upcoming,
  live,
  ended;

  /// Null when it can't be told: no start date, or a recurring event whose
  /// current occurrence is unknown or already over (the series goes on).
  static GroupEventStatus? of(GroupEvent event, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (event.isRecurring) {
      final occurrence = event.occurrenceDate;
      if (occurrence == null) return null;
      if (current.isBefore(occurrence)) return GroupEventStatus.upcoming;
      return current.isBefore(occurrence.add(GroupEventLiveUtils.liveGrace))
          ? GroupEventStatus.live
          : null;
    }
    final start = event.startDate;
    if (start == null) return null;
    if (current.isBefore(start)) return GroupEventStatus.upcoming;
    // No usable end date means live for [GroupEventLiveUtils.liveGrace].
    return GroupEventLiveUtils.hasEnded(event, current)
        ? GroupEventStatus.ended
        : GroupEventStatus.live;
  }

  String get key => name;
}

/// Product analytics for group events: one method per tracked action, so the
/// event names and their property keys live in one place. Every call fires
/// and forgets; callers fire after the server confirms, never optimistically.
class GroupEventAnalytics {
  const GroupEventAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// The event detail screen showed an event; fired once per visit.
  /// [source] is where it was opened from when the opener said so: `home`,
  /// `connect`, `group_page`, `home_banner`, `calendar`, `push`, `deep_link`
  /// or `created`.
  void eventViewed({
    required String eventId,
    required String groupId,
    required String eventTitle,
    required String? eventFormat,
    required bool isRecurring,
    String? source,
    GroupEventStatus? status,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventViewed, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.eventTitle: eventTitle,
      AnalyticsProperties.eventFormat: eventFormat,
      AnalyticsProperties.isRecurring: isRecurring,
      if (source != null) AnalyticsProperties.source: source,
      if (status != null) AnalyticsProperties.status: status.key,
    });
  }

  /// The embedded live stream started playing for this viewer.
  void eventLiveOpened({required String eventId, required String groupId}) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventLiveOpened, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
    });
  }

  /// The live stream stopped or the screen left; [durationSeconds] is the
  /// time it was actually playing.
  void eventLiveEnded({
    required String eventId,
    required String groupId,
    required int durationSeconds,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventLiveEnded, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.durationSeconds: durationSeconds,
    });
  }

  /// An online attendee picked a recording of [dayNumber] from the Replays
  /// menu; [session] is its position among that day's recordings.
  void eventReplayOpened({
    required String eventId,
    required String groupId,
    required int dayNumber,
    required int session,
    required String videoId,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventReplayOpened, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.dayNumber: dayNumber,
      AnalyticsProperties.session: session,
      AnalyticsProperties.videoId: videoId,
    });
  }

  void accumulatorViewed({
    required String groupId,
    required String accumulatorId,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.groupAccumulatorViewed, {
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.accumulatorId: accumulatorId,
    });
  }

  /// [participation] is null when the event has a single format and the
  /// server chose it.
  void eventAttended({
    required String eventId,
    required String groupId,
    required GroupEventParticipationType? participation,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventAttended, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.participation: participation?.apiValue,
    });
  }

  /// [planId] and [seriesId] name the practice the event is tied to. Leaving
  /// ends only the RSVP and chat room, so any enrollment in it stays.
  void eventLeft({
    required String eventId,
    required String groupId,
    String? planId,
    String? seriesId,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventLeft, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.planId: planId,
      AnalyticsProperties.seriesId: seriesId,
    });
  }

  /// An attendee of a hybrid event switched between online and in person.
  void eventParticipationChanged({
    required String eventId,
    required String groupId,
    required GroupEventParticipationType participation,
  }) {
    _analytics
        .trackInBackground(AnalyticsEvents.groupEventParticipationChanged, {
          AnalyticsProperties.eventId: eventId,
          AnalyticsProperties.groupId: groupId,
          AnalyticsProperties.participation: participation.apiValue,
        });
  }

  /// The attendee opened the event's practice (series or plan) from the
  /// detail screen, with the live stream when attending online.
  void eventLiveEntered({
    required String eventId,
    required String groupId,
    required GroupEventParticipationType? participation,
    required GroupEventLiveTarget target,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventLiveEntered, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.participation: participation?.apiValue,
      AnalyticsProperties.target: target.name,
    });
  }

  /// A meeting, video or web link on the event was opened.
  void eventLinkOpened({
    required String eventId,
    required String groupId,
    required GroupEventLinkKind kind,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventLinkOpened, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.linkType: kind.name,
    });
  }

  /// An admin saved an event from the composer, as a draft or published.
  /// [isEdit] is true when an existing event was changed.
  void eventSaved({
    required GroupEvent event,
    required bool isDraft,
    required bool isEdit,
  }) {
    _analytics.trackInBackground(
      isDraft
          ? AnalyticsEvents.groupEventDraftSaved
          : AnalyticsEvents.groupEventPublished,
      {
        AnalyticsProperties.eventId: event.id,
        AnalyticsProperties.groupId: event.groupId,
        AnalyticsProperties.eventFormat: event.eventFormat,
        AnalyticsProperties.isRecurring: event.isRecurring,
        AnalyticsProperties.isEdit: isEdit,
        AnalyticsProperties.hasPlan: event.planId != null,
        AnalyticsProperties.hasSeries: event.seriesId != null,
        AnalyticsProperties.hasCollection:
            event.groupRecitationCollectionId != null,
        AnalyticsProperties.hasAccumulation:
            event.accumulatorId != null ||
            event.groupAccumulatorId != null ||
            event.accumulations.isNotEmpty,
      },
    );
  }

  /// An admin deleted a draft event.
  void eventDeleted({required String eventId, required String groupId}) {
    _analytics.trackInBackground(AnalyticsEvents.groupEventDeleted, {
      AnalyticsProperties.eventId: eventId,
      AnalyticsProperties.groupId: groupId,
    });
  }
}

final groupEventAnalyticsProvider = Provider<GroupEventAnalytics>((ref) {
  return GroupEventAnalytics(ref.watch(analyticsServiceProvider));
});
