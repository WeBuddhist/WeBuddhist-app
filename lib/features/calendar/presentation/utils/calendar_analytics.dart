import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_pecha/features/calendar/domain/models/personal_calendar_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product analytics for the calendar. Personal events send how they repeat,
/// never their titles.
class CalendarAnalytics {
  const CalendarAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// The calendar screen opened, in [calendarType].
  void calendarViewed({required String calendarType}) {
    _analytics.trackInBackground(AnalyticsEvents.calendarViewed, {
      AnalyticsProperties.calendarType: calendarType,
    });
  }

  /// The viewer picked another calendar type.
  void calendarTypeChanged({required String from, required String to}) {
    _analytics.trackInBackground(AnalyticsEvents.calendarTypeChanged, {
      AnalyticsProperties.from: from,
      AnalyticsProperties.to: to,
    });
  }

  void personalEventCreated({required PersonalRepeat repeat}) {
    _analytics.trackInBackground(AnalyticsEvents.personalEventCreated, {
      AnalyticsProperties.repeats: repeatKey(repeat),
    });
  }

  void personalEventUpdated({required PersonalRepeat repeat}) {
    _analytics.trackInBackground(AnalyticsEvents.personalEventUpdated, {
      AnalyticsProperties.repeats: repeatKey(repeat),
    });
  }

  void personalEventDeleted() {
    _analytics.trackInBackground(AnalyticsEvents.personalEventDeleted, {});
  }

  /// `none`, `weekly`, `monthly_lunar`, ...
  static String repeatKey(PersonalRepeat repeat) =>
      repeat.apiValue.toLowerCase();
}

final calendarAnalyticsProvider = Provider<CalendarAnalytics>((ref) {
  return CalendarAnalytics(ref.watch(analyticsServiceProvider));
});
