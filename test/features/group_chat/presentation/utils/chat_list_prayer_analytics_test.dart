import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late GroupChatAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = GroupChatAnalytics(service);
  });

  test('the chat list says whether something is unread, once known', () async {
    analytics.chatsListOpened(hasUnread: true);
    analytics.chatsListOpened();
    await Future<void>.delayed(Duration.zero);

    expect(service.eventNames, [
      AnalyticsEvents.chatsListOpened,
      AnalyticsEvents.chatsListOpened,
    ]);
    expect(service.events.first.properties, {'has_unread': true});
    expect(service.events.last.properties, isEmpty);
  });

  test('a prayer list names its scope and what opened it', () async {
    analytics.prayerRequestsOpened(
      scope: 'event',
      eventId: 'e1',
      source: 'event_page',
    );
    analytics.prayerRequestsOpened(scope: 'mine');
    await Future<void>.delayed(Duration.zero);

    expect(service.events.first.properties, {
      'scope': 'event',
      'event_id': 'e1',
      'source': 'event_page',
    });
    expect(service.events.last.properties, {'scope': 'mine'});
  });
}
