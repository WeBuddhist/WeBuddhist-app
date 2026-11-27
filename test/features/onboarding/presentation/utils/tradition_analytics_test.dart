import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/no_op_analytics_service.dart';
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

  test('the traditions go on the person, the event carries only how many', () {
    analytics.traditionsChanged(
      codes: const ['pali', 'tibetan'],
      isFirstReport: false,
    );

    expect(service.eventNames, [AnalyticsEvents.traditionsChanged]);
    expect(service.events.single.properties, {
      'traditions_count': 2,
      'is_first_report': false,
      r'$set': {
        'traditions': ['theravada', 'vajrayana'],
      },
    });
  });

  test('each server code is sent as the name of its tradition, sorted', () {
    expect(TraditionAnalytics.traditionNames(const ['tibetan', 'chinese']), [
      'mahayana',
      'vajrayana',
    ]);
    expect(TraditionAnalytics.traditionNames(const ['pali']), ['theravada']);
    expect(TraditionAnalytics.traditionNames(const []), isEmpty);
  });

  test('a code with no known name is sent as it is', () {
    expect(TraditionAnalytics.traditionNames(const ['pali', 'newer']), [
      'newer',
      'theravada',
    ]);
  });

  test('no tradition is an event property', () {
    analytics.traditionsChanged(codes: const ['chinese'], isFirstReport: true);

    final eventProperties = Map.of(service.events.single.properties)
      ..remove(r'$set');
    expect(eventProperties.keys, isNot(contains('traditions')));
    expect(eventProperties.values, isNot(contains('chinese')));
    expect(eventProperties.values, isNot(contains('mahayana')));
  });

  test('a report can be made unless analytics says it is off', () {
    expect(analytics.canReport, isTrue);
    expect(
      const TraditionAnalytics(NoOpAnalyticsService()).canReport,
      isFalse,
    );
  });
}
