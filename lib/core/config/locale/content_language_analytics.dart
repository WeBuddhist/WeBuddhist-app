import 'dart:async';

import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What changed the content language, carried on `content_language_changed`.
/// `reconcile` is the backend kill switch replacing a disabled language.
enum ContentLanguageSource { settings, onboarding, reconcile }

/// Fires once the new code is persisted, never for re-selecting the current
/// one.
class ContentLanguageAnalytics {
  const ContentLanguageAnalytics(this._analytics);

  final AnalyticsService _analytics;

  void contentLanguageChanged({
    required String from,
    required String to,
    ContentLanguageSource? source,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.contentLanguageChanged, {
      AnalyticsProperties.from: from,
      AnalyticsProperties.to: to,
      AnalyticsProperties.source: source?.name,
      AnalyticsProperties.personSet: {AnalyticsProperties.contentLanguage: to},
    });
  }

  /// The app (UI) language changed after start-up. Also updates `ui_language`
  /// on the user's PostHog profile, which is otherwise only set at login.
  void uiLanguageChanged({required String from, required String to}) {
    _analytics.trackInBackground(AnalyticsEvents.uiLanguageChanged, {
      AnalyticsProperties.from: from,
      AnalyticsProperties.to: to,
      AnalyticsProperties.personSet: {AnalyticsProperties.uiLanguage: to},
    });
  }

  /// Adds the current languages to every later event. Called when each is
  /// first known and whenever it changes.
  void languagesInUse({String? uiLanguage, String? contentLanguage}) {
    unawaited(
      _analytics
          .setSuperProperties({
            if (uiLanguage != null) AnalyticsProperties.uiLanguage: uiLanguage,
            if (contentLanguage != null)
              AnalyticsProperties.contentLanguage: contentLanguage,
          })
          .catchError((Object _) {}),
    );
  }
}

final contentLanguageAnalyticsProvider = Provider<ContentLanguageAnalytics>((
  ref,
) {
  return ContentLanguageAnalytics(ref.watch(analyticsServiceProvider));
});
