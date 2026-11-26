import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/entry_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late EntryAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = EntryAnalytics(service);
  });

  test('a deep link carries its utm values when it has them', () {
    analytics.deepLinkOpened(
      source: 'app_links',
      routeKind: 'event',
      targetId: 'e1',
      utmSource: 'instagram',
      utmCampaign: 'tara_2026',
    );

    expect(service.events.single.properties, {
      'source': 'app_links',
      'route_kind': 'event',
      'target_id': 'e1',
      'utm_source': 'instagram',
      'utm_campaign': 'tara_2026',
    });
  });

  test('deepLinkOpened carries the handler, route kind and target', () {
    analytics.deepLinkOpened(
      source: 'app_links',
      routeKind: 'series',
      targetId: 's1',
    );

    expect(service.eventNames, [AnalyticsEvents.deepLinkOpened]);
    expect(service.events.single.properties, {
      'source': 'app_links',
      'route_kind': 'series',
      'target_id': 's1',
    });
  });

  test('pushNotificationOpened carries the payload ids and app state', () {
    analytics.pushNotificationOpened(
      appState: PushAppState.terminated,
      sessionType: 'PLAN',
      sourceId: 'p1',
    );

    expect(service.eventNames, [AnalyticsEvents.pushNotificationOpened]);
    expect(service.events.single.properties, {
      'session_type': 'PLAN',
      'source_id': 'p1',
      'app_state': 'terminated',
    });
  });

  test('pushNotificationOpened carries the notification id and campaign', () {
    analytics.pushNotificationOpened(
      appState: PushAppState.background,
      sessionType: 'PLAN',
      notificationId: 'n1',
      campaign: 'losar',
    );

    expect(service.events.single.properties, {
      'session_type': 'PLAN',
      'source_id': null,
      'app_state': 'background',
      'notification_id': 'n1',
      'campaign': 'losar',
    });
  });

  test('localNotificationOpened carries the type and lateness', () {
    analytics.localNotificationOpened(
      type: 'recitation',
      minutesAfterScheduled: 12,
    );

    expect(service.eventNames, [AnalyticsEvents.localNotificationOpened]);
    expect(service.events.single.properties, {
      'type': 'recitation',
      'minutes_after_scheduled': 12,
    });
  });

  test('the permission prompt and its answer name the OS', () {
    analytics.notificationPermissionPrompted(os: NotificationOs.ios);
    analytics.notificationPermissionAnswered(
      granted: true,
      os: NotificationOs.ios,
    );
    analytics.notificationPermissionAnswered(
      granted: false,
      os: NotificationOs.android,
    );

    expect(service.eventNames, [
      AnalyticsEvents.notificationPermissionPrompted,
      AnalyticsEvents.notificationPermissionGranted,
      AnalyticsEvents.notificationPermissionDenied,
    ]);
    expect(service.events.first.properties, {'os': 'ios'});
    expect(service.events.last.properties, {'os': 'android'});
  });

  test('minutesSinceScheduled wraps around midnight', () {
    // 07:10 reminder tapped at 07:25.
    expect(
      minutesSinceScheduled(7 * 60 + 10, DateTime(2026, 9, 24, 7, 25)),
      15,
    );
    // 23:50 reminder tapped at 00:05 the next day.
    expect(
      minutesSinceScheduled(23 * 60 + 50, DateTime(2026, 9, 25, 0, 5)),
      15,
    );
  });
}
