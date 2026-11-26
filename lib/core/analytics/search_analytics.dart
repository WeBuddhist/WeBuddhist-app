import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which search box a search ran in, carried as `surface`.
enum SearchSurface {
  plans,
  recitations,
  accumulations,
  groups,
  reader,

  /// The Practice tab's search, which runs every search above at once.
  practice;

  String get key => name;
}

/// Product analytics shared by every search box. Only the length of a query
/// is sent: the text itself could be personal.
class SearchAnalytics {
  const SearchAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// A search returned its first page of [resultCount] results.
  void searched({
    required SearchSurface surface,
    required String query,
    required int resultCount,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.searchPerformed, {
      AnalyticsProperties.surface: surface.key,
      AnalyticsProperties.queryLength: query.trim().length,
      AnalyticsProperties.resultCount: resultCount,
    });
  }

  /// A result was opened; [position] is its index in the list, from 0.
  void resultOpened({
    required SearchSurface surface,
    required int position,
    required String itemType,
    String? itemId,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.searchResultOpened, {
      AnalyticsProperties.surface: surface.key,
      AnalyticsProperties.position: position,
      AnalyticsProperties.itemType: itemType,
      if (itemId != null) AnalyticsProperties.itemId: itemId,
    });
  }
}

final searchAnalyticsProvider = Provider<SearchAnalytics>((ref) {
  return SearchAnalytics(ref.watch(analyticsServiceProvider));
});
