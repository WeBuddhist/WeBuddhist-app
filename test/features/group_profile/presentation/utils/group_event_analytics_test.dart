import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_event.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_analytics.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_link_utils.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_live_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late GroupEventAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = GroupEventAnalytics(service);
  });

  test('a view carries where it was opened from and the event status', () {
    analytics.eventViewed(
      eventId: 'e1',
      groupId: 'g1',
      eventTitle: 'Tara',
      eventFormat: null,
      isRecurring: false,
      source: 'home',
      status: GroupEventStatus.live,
    );

    expect(service.events.single.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
      'event_title': 'Tara',
      'event_format': null,
      'is_recurring': false,
      'source': 'home',
      'status': 'live',
    });
  });

  test('the status follows the event times', () {
    final now = DateTime(2026, 11, 24, 12);
    GroupEvent event({DateTime? start, DateTime? end}) =>
        GroupEvent(id: 'e1', groupId: 'g1', startDate: start, endDate: end);

    expect(
      GroupEventStatus.of(
        event(start: DateTime(2026, 11, 25), end: DateTime(2026, 11, 25, 2)),
        now: now,
      ),
      GroupEventStatus.upcoming,
    );
    expect(
      GroupEventStatus.of(
        event(start: DateTime(2026, 11, 24, 11), end: DateTime(2026, 11, 24, 13)),
        now: now,
      ),
      GroupEventStatus.live,
    );
    expect(
      GroupEventStatus.of(
        event(start: DateTime(2026, 11, 23), end: DateTime(2026, 11, 23, 2)),
        now: now,
      ),
      GroupEventStatus.ended,
    );
    expect(GroupEventStatus.of(event(), now: now), isNull);
  });

  test('an event without an end date is live for the grace period', () {
    final start = DateTime(2026, 11, 24, 10);
    final event = GroupEvent(id: 'e1', groupId: 'g1', startDate: start);

    expect(
      GroupEventStatus.of(event, now: start.add(const Duration(hours: 1))),
      GroupEventStatus.live,
    );
    expect(
      GroupEventStatus.of(
        event,
        now: start.add(GroupEventLiveUtils.liveGrace),
      ),
      GroupEventStatus.ended,
    );
  });

  test('a recurring event follows its current occurrence', () {
    final occurrence = DateTime(2026, 11, 24, 10);
    GroupEvent event({DateTime? occurrenceDate}) => GroupEvent(
      id: 'e1',
      groupId: 'g1',
      startDate: DateTime(2026, 1, 1, 10),
      endDate: DateTime(2026, 12, 31, 11),
      isRecurring: true,
      occurrenceDate: occurrenceDate,
    );

    expect(
      GroupEventStatus.of(
        event(occurrenceDate: occurrence),
        now: occurrence.subtract(const Duration(hours: 1)),
      ),
      GroupEventStatus.upcoming,
    );
    expect(
      GroupEventStatus.of(
        event(occurrenceDate: occurrence),
        now: occurrence.add(const Duration(minutes: 30)),
      ),
      GroupEventStatus.live,
    );
    // Past the occurrence, or with none known: no status rather than a guess.
    expect(
      GroupEventStatus.of(
        event(occurrenceDate: occurrence),
        now: occurrence.add(const Duration(days: 1)),
      ),
      isNull,
    );
    expect(GroupEventStatus.of(event(), now: occurrence), isNull);
  });

  test('eventViewed carries the event, its group and format', () {
    analytics.eventViewed(
      eventId: 'e1',
      groupId: 'g1',
      eventTitle: 'Tara Feast Offerings',
      eventFormat: 'hybrid',
      isRecurring: true,
    );

    expect(service.eventNames, [AnalyticsEvents.groupEventViewed]);
    expect(service.events.single.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
      'event_title': 'Tara Feast Offerings',
      'event_format': 'hybrid',
      'is_recurring': true,
    });
  });

  test('attending a single-format event has no participation', () {
    analytics.eventAttended(eventId: 'e1', groupId: 'g1', participation: null);

    expect(service.events.single.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
      'participation': null,
    });
  });

  test('participation is reported by its API value', () {
    analytics.eventParticipationChanged(
      eventId: 'e1',
      groupId: 'g1',
      participation: GroupEventParticipationType.offline,
    );
    analytics.eventLiveEntered(
      eventId: 'e1',
      groupId: 'g1',
      participation: GroupEventParticipationType.online,
      target: GroupEventLiveTarget.series,
    );

    expect(service.eventNames, [
      AnalyticsEvents.groupEventParticipationChanged,
      AnalyticsEvents.groupEventLiveEntered,
    ]);
    expect(service.events.first.properties['participation'], 'offline');
    expect(service.events.last.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
      'participation': 'online',
      'target': 'series',
    });
  });

  test('leave and link open fire their own events', () {
    analytics.eventLeft(eventId: 'e1', groupId: 'g1', planId: 'p1');
    analytics.eventLinkOpened(
      eventId: 'e1',
      groupId: 'g1',
      kind: GroupEventLinkKind.meeting,
    );

    expect(service.eventNames, [
      AnalyticsEvents.groupEventLeft,
      AnalyticsEvents.groupEventLinkOpened,
    ]);
    expect(service.events.first.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
      'plan_id': 'p1',
      'series_id': null,
    });
    expect(service.events.last.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
      'link_type': 'meeting',
    });
  });

  test('a picked replay carries its day, session and video', () {
    analytics.eventReplayOpened(
      eventId: 'e1',
      groupId: 'g1',
      dayNumber: 3,
      session: 2,
      videoId: 'dQw4w9WgXcQ',
    );

    expect(service.eventNames, [AnalyticsEvents.groupEventReplayOpened]);
    expect(service.events.single.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
      'day_number': 3,
      'session': 2,
      'video_id': 'dQw4w9WgXcQ',
    });
  });
}
