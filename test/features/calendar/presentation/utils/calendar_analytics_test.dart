import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/calendar/domain/models/personal_calendar_event.dart';
import 'package:flutter_pecha/features/calendar/presentation/utils/calendar_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late CalendarAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = CalendarAnalytics(service);
  });

  test('viewing and switching the calendar type', () {
    analytics.calendarViewed(calendarType: 'tibetan');
    analytics.calendarTypeChanged(from: 'tibetan', to: 'bhutanese');

    expect(service.eventNames, [
      AnalyticsEvents.calendarViewed,
      AnalyticsEvents.calendarTypeChanged,
    ]);
    expect(service.events.first.properties, {'calendar_type': 'tibetan'});
    expect(service.events.last.properties, {
      'from': 'tibetan',
      'to': 'bhutanese',
    });
  });

  test('personal events send how they repeat, never a title', () {
    analytics.personalEventCreated(repeat: PersonalRepeat.monthlyLunar);
    analytics.personalEventUpdated(repeat: PersonalRepeat.none);
    analytics.personalEventDeleted();

    expect(service.eventNames, [
      AnalyticsEvents.personalEventCreated,
      AnalyticsEvents.personalEventUpdated,
      AnalyticsEvents.personalEventDeleted,
    ]);
    expect(service.events[0].properties, {'repeats': 'monthly_lunar'});
    expect(service.events[1].properties, {'repeats': 'none'});
    expect(service.events[2].properties, isEmpty);
  });
}
