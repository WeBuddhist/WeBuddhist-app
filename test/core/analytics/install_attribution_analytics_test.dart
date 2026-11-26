import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/app_open_analytics.dart';
import 'package:flutter_pecha/core/analytics/install_attribution_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recording_analytics_service.dart';

class _MemoryStore implements AppOpenStore {
  final Map<String, Object> values = {};

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  late RecordingAnalyticsService service;
  late _MemoryStore store;
  late InstallAttributionAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    store = _MemoryStore();
    analytics = InstallAttributionAnalytics(service, store);
  });

  test('the install campaign is sent once, also as set-once person data', () async {
    await analytics.attributionReceived({
      'attributedChannel': 'instagram',
      'attributedCampaign': ' tara_2026 ',
      'attributedAdGroup': '',
      'attributedContent': 'reel',
    });

    expect(service.eventNames, [AnalyticsEvents.installAttributed]);
    const expected = {
      'acquisition_channel': 'instagram',
      'acquisition_campaign': 'tara_2026',
    };
    expect(service.events.single.properties, {
      ...expected,
      r'$set_once': expected,
    });
    expect(store.values[InstallAttributionAnalytics.sentKey], isTrue);
  });

  test('a later attribution for the same install is not sent again', () async {
    await analytics.attributionReceived({'attributedChannel': 'instagram'});
    await analytics.attributionReceived({'attributedChannel': 'facebook'});

    expect(service.eventNames, [AnalyticsEvents.installAttributed]);
  });

  test('two callbacks arriving together send one event', () async {
    await Future.wait([
      analytics.attributionReceived({'attributedChannel': 'instagram'}),
      analytics.attributionReceived({'attributedChannel': 'facebook'}),
    ]);

    expect(service.eventNames, [AnalyticsEvents.installAttributed]);
    expect(
      service.events.single.properties['acquisition_channel'],
      'instagram',
    );
  });

  test('an attribution without channel or campaign sends nothing', () async {
    await analytics.attributionReceived({'attributedAdCreative': 'banner'});

    expect(service.events, isEmpty);
    expect(store.values, isEmpty);
  });
}
