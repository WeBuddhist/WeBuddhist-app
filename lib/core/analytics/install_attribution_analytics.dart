import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_pecha/core/analytics/app_open_analytics.dart';

/// Sends Airbridge's install attribution to PostHog, once per install: as an
/// `install_attributed` event, and with `$set_once` on the person, so later
/// logins and later attribution callbacks never overwrite the first source.
class InstallAttributionAnalytics {
  InstallAttributionAnalytics(this._analytics, this._store);

  final AnalyticsService _analytics;

  /// The same store as app-open tracking, which logout does not clear.
  final AppOpenStore _store;

  static const String sentKey = 'analytics_install_attribution_sent';

  /// Set by the first call that gets past validation, before anything is
  /// awaited. Airbridge callbacks are not awaited, so two can overlap; this
  /// stops the second from reading the stored flag before the first writes it.
  bool _claimed = false;

  /// Airbridge's attribution field for each property sent.
  static const Map<String, String> _fields = {
    AnalyticsProperties.acquisitionChannel: 'attributedChannel',
    AnalyticsProperties.acquisitionCampaign: 'attributedCampaign',
    AnalyticsProperties.acquisitionAdGroup: 'attributedAdGroup',
    AnalyticsProperties.acquisitionAdCreative: 'attributedAdCreative',
  };

  /// [attribution] is the map `Airbridge.setOnAttributionReceived` delivers.
  /// Does nothing when it names no channel or campaign, or when this install
  /// already sent one, including from a call still in flight.
  Future<void> attributionReceived(Map<String, String> attribution) async {
    final values = <String, String>{
      for (final MapEntry(key: property, value: field) in _fields.entries)
        if (_clean(attribution[field]) case final value?) property: value,
    };
    if (!values.containsKey(AnalyticsProperties.acquisitionChannel) &&
        !values.containsKey(AnalyticsProperties.acquisitionCampaign)) {
      return;
    }
    if (_claimed) return;
    _claimed = true;
    if (await _store.getBool(sentKey) == true) return;
    await _store.setBool(sentKey, true);

    _analytics.trackInBackground(AnalyticsEvents.installAttributed, {
      ...values,
      r'$set_once': values,
    });
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
