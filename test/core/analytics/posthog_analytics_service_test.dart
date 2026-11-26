import 'package:flutter_pecha/core/analytics/clarity_screen_observer.dart';
import 'package:flutter_pecha/core/analytics/posthog_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an event with a group id carries the sangha in \$groups', () {
    expect(
      PostHogAnalyticsService.withSanghaGroup({'group_id': 'g1', 'x': 1}),
      {
        'group_id': 'g1',
        'x': 1,
        r'$groups': {'sangha': 'g1'},
      },
    );
  });

  test('build_mode is debug outside release and profile builds', () {
    expect(PostHogAnalyticsService.buildMode, 'debug');
  });

  test('events without a group id are untouched', () {
    expect(PostHogAnalyticsService.withSanghaGroup({'x': 1}), {'x': 1});
    expect(PostHogAnalyticsService.withSanghaGroup({'group_id': ''}), {
      'group_id': '',
    });
    expect(PostHogAnalyticsService.withSanghaGroup(null), isNull);
  });

  test('screens come from the screen tracker, not PosthogObserver', () {
    final observers = PostHogAnalyticsService.instance.routeObservers;

    // PosthogObserver stays only for the context surveys are shown in.
    expect(observers.whereType<PosthogObserver>(), hasLength(1));
    expect(observers.whereType<ClarityScreenObserver>(), hasLength(1));
  });

  test('first_app_version goes out with a login, not a restored session', () {
    expect(
      PostHogAnalyticsService.setOnceProperties(
        properties: {'is_guest': false},
        appVersion: '2.48.0',
      ),
      {'first_app_version': '2.48.0'},
    );
    // A cold start re-identifies without person properties.
    expect(
      PostHogAnalyticsService.setOnceProperties(
        properties: null,
        appVersion: '2.48.0',
      ),
      isNull,
    );
    expect(
      PostHogAnalyticsService.setOnceProperties(
        properties: {'is_guest': false},
        appVersion: null,
      ),
      isNull,
    );
  });
}
