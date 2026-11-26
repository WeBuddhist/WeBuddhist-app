import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_event.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late GroupEventAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = GroupEventAnalytics(service);
  });

  test('publishing says what the event holds', () {
    analytics.eventSaved(
      event: const GroupEvent(
        id: 'e1',
        groupId: 'g1',
        isRecurring: true,
        planId: 'p1',
        eventFormat: 'online',
      ),
      isDraft: false,
      isEdit: false,
    );

    expect(service.events.single.name, AnalyticsEvents.groupEventPublished);
    expect(service.events.single.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
      'event_format': 'online',
      'is_recurring': true,
      'is_edit': false,
      'has_plan': true,
      'has_series': false,
      'has_collection': false,
      'has_accumulation': false,
    });
  });

  test('a draft save and a draft delete have their own events', () {
    analytics.eventSaved(
      event: const GroupEvent(id: 'e1', groupId: 'g1'),
      isDraft: true,
      isEdit: true,
    );
    analytics.eventDeleted(eventId: 'e1', groupId: 'g1');

    expect(service.eventNames, [
      AnalyticsEvents.groupEventDraftSaved,
      AnalyticsEvents.groupEventDeleted,
    ]);
    expect(service.events.last.properties, {
      'event_id': 'e1',
      'group_id': 'g1',
    });
  });
}
