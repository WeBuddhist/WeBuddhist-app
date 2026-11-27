import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/onboarding/presentation/utils/tradition_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late TraditionAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = TraditionAnalytics(service);
  });

  test('the codes go on the person, the event carries only how many', () {
    analytics.traditionsChanged(
      codes: const ['pali', 'tibetan'],
      isFirstReport: false,
    );

    expect(service.eventNames, [AnalyticsEvents.traditionsChanged]);
    expect(service.events.single.properties, {
      'traditions_count': 2,
      'is_first_report': false,
      r'$set': {
        'traditions': ['pali', 'tibetan'],
      },
    });
  });

  test('no tradition code is an event property', () {
    analytics.traditionsChanged(codes: const ['chinese'], isFirstReport: true);

    final eventProperties = Map.of(service.events.single.properties)
      ..remove(r'$set');
    expect(eventProperties.values, isNot(contains('chinese')));
    expect(eventProperties.keys, isNot(contains('traditions')));
  });
}
