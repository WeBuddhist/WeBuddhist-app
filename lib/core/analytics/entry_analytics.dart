import 'dart:io';

import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App state when a push was tapped, carried on `push_notification_opened`.
enum PushAppState { foreground, background, terminated }

/// Whose permission dialog was shown, carried on the permission events.
enum NotificationOs { android, ios }

/// The running OS. macOS counts as iOS, as the notification code treats it.
NotificationOs get currentNotificationOs =>
    Platform.isAndroid ? NotificationOs.android : NotificationOs.ios;

/// Minutes since the last daily occurrence of [scheduledMinuteOfDay].
int minutesSinceScheduled(int scheduledMinuteOfDay, DateTime now) {
  final nowMinute = now.hour * 60 + now.minute;
  return (nowMinute - scheduledMinuteOfDay) % Duration.minutesPerDay;
}

/// Product analytics for the ways into the app: deep links, notification taps
/// and the OS notification permission. One method per tracked action; every
/// call fires and forgets, after the link or tap was actually routed.
class EntryAnalytics {
  const EntryAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// A deep link was routed to a screen. [source] is the handler that got it
  /// (`app_links` or `airbridge`).
  /// [utmSource], [utmMedium] and [utmCampaign] are the link's own `utm_*`
  /// query values, sent only when the link had them.
  void deepLinkOpened({
    required String source,
    required String routeKind,
    String? targetId,
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.deepLinkOpened, {
      AnalyticsProperties.source: source,
      AnalyticsProperties.routeKind: routeKind,
      AnalyticsProperties.targetId: targetId,
      if (utmSource != null) AnalyticsProperties.utmSource: utmSource,
      if (utmMedium != null) AnalyticsProperties.utmMedium: utmMedium,
      if (utmCampaign != null) AnalyticsProperties.utmCampaign: utmCampaign,
    });
  }

  /// A push tap was routed. [sessionType] and [sourceId] are the payload's
  /// own values, null when it carried none.
  ///
  /// [notificationId] and [campaign] come from the push data once the backend
  /// sends them; they are left out until then.
  void pushNotificationOpened({
    required PushAppState appState,
    String? sessionType,
    String? sourceId,
    String? notificationId,
    String? campaign,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.pushNotificationOpened, {
      AnalyticsProperties.sessionType: sessionType,
      AnalyticsProperties.sourceId: sourceId,
      AnalyticsProperties.appState: appState.name,
      if (notificationId != null)
        AnalyticsProperties.notificationId: notificationId,
      if (campaign != null) AnalyticsProperties.campaign: campaign,
    });
  }

  /// A local notification tap was handled. [type] is the payload's routine
  /// item type (`recitation`, `timer`, `accumulator`, ...) or `timer_session`.
  void localNotificationOpened({
    required String type,
    int? minutesAfterScheduled,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.localNotificationOpened, {
      AnalyticsProperties.type: type,
      AnalyticsProperties.minutesAfterScheduled: minutesAfterScheduled,
    });
  }

  /// The OS notification dialog is being shown.
  void notificationPermissionPrompted({NotificationOs? os}) {
    _analytics.trackInBackground(
      AnalyticsEvents.notificationPermissionPrompted,
      {AnalyticsProperties.os: (os ?? currentNotificationOs).name},
    );
  }

  /// The dialog returned: `notification_permission_granted` or `_denied`.
  void notificationPermissionAnswered({
    required bool granted,
    NotificationOs? os,
  }) {
    _analytics.trackInBackground(
      granted
          ? AnalyticsEvents.notificationPermissionGranted
          : AnalyticsEvents.notificationPermissionDenied,
      {AnalyticsProperties.os: (os ?? currentNotificationOs).name},
    );
  }
}

final entryAnalyticsProvider = Provider<EntryAnalytics>((ref) {
  return EntryAnalytics(ref.watch(analyticsServiceProvider));
});
