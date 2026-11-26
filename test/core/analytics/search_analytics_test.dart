import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/search_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late SearchAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = SearchAnalytics(service);
  });

  test('a search sends the query length, never its text', () {
    analytics.searched(
      surface: SearchSurface.recitations,
      query: '  tara  ',
      resultCount: 7,
    );

    expect(service.eventNames, [AnalyticsEvents.searchPerformed]);
    expect(service.events.single.properties, {
      'surface': 'recitations',
      'query_length': 4,
      'result_count': 7,
    });
  });

  test('an opened result carries its position and type', () {
    analytics.resultOpened(
      surface: SearchSurface.groups,
      position: 2,
      itemType: 'group',
      itemId: 'g1',
    );
    analytics.resultOpened(
      surface: SearchSurface.reader,
      position: 0,
      itemType: 'segment',
    );

    expect(service.eventNames, [
      AnalyticsEvents.searchResultOpened,
      AnalyticsEvents.searchResultOpened,
    ]);
    expect(service.events.first.properties, {
      'surface': 'groups',
      'position': 2,
      'item_type': 'group',
      'item_id': 'g1',
    });
    expect(service.events.last.properties, {
      'surface': 'reader',
      'position': 0,
      'item_type': 'segment',
    });
  });
}
