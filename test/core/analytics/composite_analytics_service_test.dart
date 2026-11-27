import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/composite_analytics_service.dart';
import 'package:flutter_pecha/core/analytics/no_op_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyAnalyticsService implements AnalyticsService {
  final List<String> calls = [];

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  Future<void> identify({
    required String userId,
    Map<String, Object?>? properties,
  }) async => calls.add('identify:$userId');

  @override
  Future<void> reset() async => calls.add('reset');

  @override
  Future<void> track(String event, {Map<String, Object?>? properties}) async =>
      calls.add('track:$event');

  @override
  Future<void> setSuperProperties(Map<String, Object?> properties) async =>
      calls.add('super:${properties.keys.join(',')}');

  @override
  List<NavigatorObserver> get routeObservers => [NavigatorObserver()];
}

/// A backend that keeps person profiles, on or off.
class _ProfileAnalyticsService extends _SpyAnalyticsService
    implements PersonProfileAnalytics {
  _ProfileAnalyticsService({required this.acceptsPersonProperties});

  @override
  final bool acceptsPersonProperties;
}

class _FailingAnalyticsService extends _SpyAnalyticsService {
  @override
  Future<void> identify({
    required String userId,
    Map<String, Object?>? properties,
  }) async {
    throw StateError('backend down');
  }
}

void main() {
  test('fans every call out to each backend', () async {
    final _SpyAnalyticsService first = _SpyAnalyticsService();
    final _SpyAnalyticsService second = _SpyAnalyticsService();
    final CompositeAnalyticsService composite = CompositeAnalyticsService([
      first,
      second,
    ]);

    await composite.initialize();
    await composite.identify(userId: 'u1');
    await composite.track('plan_viewed');
    await composite.setSuperProperties({'is_guest': true});
    await composite.reset();

    const List<String> expected = [
      'initialize',
      'identify:u1',
      'track:plan_viewed',
      'super:is_guest',
      'reset',
    ];
    expect(first.calls, expected);
    expect(second.calls, expected);
  });

  test('returns one observer per backend', () {
    final CompositeAnalyticsService composite = CompositeAnalyticsService([
      _SpyAnalyticsService(),
      _SpyAnalyticsService(),
    ]);

    expect(composite.routeObservers, hasLength(2));
  });

  test('a failing backend does not block the others', () async {
    final _SpyAnalyticsService healthy = _SpyAnalyticsService();
    final CompositeAnalyticsService composite = CompositeAnalyticsService([
      _FailingAnalyticsService(),
      healthy,
    ]);

    await composite.identify(userId: 'u1');

    expect(healthy.calls, ['identify:u1']);
  });

  group('person properties', () {
    test('are accepted when a backend that keeps profiles is on', () {
      final CompositeAnalyticsService composite = CompositeAnalyticsService([
        _ProfileAnalyticsService(acceptsPersonProperties: true),
        _SpyAnalyticsService(),
      ]);

      expect(composite.acceptsPersonProperties, isTrue);
      expect(composite.canStorePersonProperties, isTrue);
    });

    test('are not accepted when that backend is off, whatever else runs', () {
      final CompositeAnalyticsService composite = CompositeAnalyticsService([
        const NoOpAnalyticsService(),
        _SpyAnalyticsService(),
      ]);

      expect(composite.acceptsPersonProperties, isFalse);
      expect(composite.canStorePersonProperties, isFalse);
    });

    test('a service that cannot say is taken to accept them', () {
      final AnalyticsService unknown = _SpyAnalyticsService();

      expect(unknown.canStorePersonProperties, isTrue);
      expect(
        const NoOpAnalyticsService().canStorePersonProperties,
        isFalse,
      );
    });
  });
}
