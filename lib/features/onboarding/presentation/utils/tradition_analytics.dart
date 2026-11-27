import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product analytics for the traditions an account follows.
///
/// The codes (`pali`, `chinese`, `tibetan`) go on the person only, inside
/// `$set`. They are never an event property: Clarity tags event properties
/// but skips `$` keys, so which traditions someone follows stays out of
/// session recordings. The event itself carries only how many.
class TraditionAnalytics {
  const TraditionAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// The account's traditions, as the server has them, differ from what this
  /// device last reported. [isFirstReport] is true when nothing was reported
  /// for the account before, which tells the first sync of an existing
  /// account from a later edit.
  void traditionsChanged({
    required List<String> codes,
    required bool isFirstReport,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.traditionsChanged, {
      AnalyticsProperties.traditionsCount: codes.length,
      AnalyticsProperties.isFirstReport: isFirstReport,
      AnalyticsProperties.personSet: {AnalyticsProperties.traditions: codes},
    });
  }
}

final traditionAnalyticsProvider = Provider<TraditionAnalytics>((ref) {
  return TraditionAnalytics(ref.watch(analyticsServiceProvider));
});
