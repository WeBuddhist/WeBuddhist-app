import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/analytics/analytics_tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Home section a tap came from, carried on `home_card_tapped`.
/// The share and feedback prompts are not here: `content_shared` and
/// `help_contact_opened` already record them.
enum HomeSection {
  shortcuts,
  stats,
  featuredPlan,
  groupEvents,
  poems,
  eventBanner;

  String get key => switch (this) {
    HomeSection.featuredPlan => 'featured_plan',
    HomeSection.groupEvents => 'group_events',
    HomeSection.eventBanner => 'event_banner',
    _ => name,
  };
}

/// Product analytics for the Home tab. Every call fires and forgets.
class HomeAnalytics {
  const HomeAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// The Home tab was shown; [streakCurrent] is null until the streak loads.
  void homeViewed({
    required bool hasRoutine,
    required int? streakCurrent,
    required bool isGuest,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.homeViewed, {
      AnalyticsProperties.hasRoutine: hasRoutine,
      AnalyticsProperties.streakCurrent: streakCurrent,
      AnalyticsProperties.isGuest: isGuest,
    });
  }

  /// The selected bottom tab changed; [tab] is `home`, `practice`, `connect`
  /// or `me`. The tab shown at launch is not a change, so it is not tracked.
  void tabViewed({required String tab}) {
    _analytics.trackInBackground(AnalyticsEvents.tabViewed, {
      AnalyticsProperties.tab: tab,
    });
  }

  /// A Home section was tapped. [targetId] is what it opens (a plan, event,
  /// poem or shortcut), [position] its index in a list or carousel.
  void cardTapped({
    required HomeSection section,
    String? targetId,
    int? position,
  }) {
    _analytics.trackInBackground(AnalyticsEvents.homeCardTapped, {
      AnalyticsProperties.section: section.key,
      if (targetId != null) AnalyticsProperties.targetId: targetId,
      if (position != null) AnalyticsProperties.position: position,
    });
  }

  /// The server accepted a like or unlike of the verse of the day.
  void verseLikeChanged({required String verseId, required bool liked}) {
    _analytics.trackInBackground(
      liked ? AnalyticsEvents.verseLiked : AnalyticsEvents.verseUnliked,
      {AnalyticsProperties.verseId: verseId},
    );
  }

  /// The server accepted a comment on the verse of the day. The text is never
  /// sent.
  void verseCommentPosted({required String verseId, required bool isReply}) {
    _analytics.trackInBackground(AnalyticsEvents.verseCommentPosted, {
      AnalyticsProperties.verseId: verseId,
      AnalyticsProperties.isReply: isReply,
    });
  }
}

final homeAnalyticsProvider = Provider<HomeAnalytics>((ref) {
  return HomeAnalytics(ref.watch(analyticsServiceProvider));
});
