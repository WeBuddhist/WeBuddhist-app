import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product analytics for the traditions an account follows.
///
/// The traditions go on the person only, inside `$set`. They are never an
/// event property: Clarity tags event properties but skips `$` keys, so which
/// traditions someone follows stays out of session recordings. The event
/// itself carries only how many.
class TraditionAnalytics {
  const TraditionAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// The server's tradition codes are named after each canon's language;
  /// analytics gets the tradition's own name, which is what a reader of a
  /// chart expects.
  static const Map<String, String> _names = {
    'pali': 'theravada',
    'chinese': 'mahayana',
    'tibetan': 'vajrayana',
  };

  /// The names sent for [codes], sorted. A code with no name here (one the
  /// server added later) is sent as it is, so it still shows up.
  static List<String> traditionNames(List<String> codes) {
    return {for (final code in codes) _names[code] ?? code}.toList()..sort();
  }

  /// The account's traditions, as the server has them, differ from what this
  /// device last reported. [codes] are the server's codes. [isFirstReport] is
  /// true when nothing was reported for the account before, which tells the
  /// first sync of an existing account from a later edit.
  void traditionsChanged({
    required List<String> codes,
    required bool isFirstReport,
  }) {
    final names = traditionNames(codes);
    _analytics.trackInBackground(AnalyticsEvents.traditionsChanged, {
      AnalyticsProperties.traditionsCount: names.length,
      AnalyticsProperties.isFirstReport: isFirstReport,
      AnalyticsProperties.personSet: {AnalyticsProperties.traditions: names},
    });
  }
}

final traditionAnalyticsProvider = Provider<TraditionAnalytics>((ref) {
  return TraditionAnalytics(ref.watch(analyticsServiceProvider));
});
