import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/home/presentation/utils/home_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  test('home_card_tapped names the section, target and position', () {
    final service = RecordingAnalyticsService();
    HomeAnalytics(service)
      ..cardTapped(section: HomeSection.featuredPlan, targetId: 's1')
      ..cardTapped(section: HomeSection.poems, targetId: 'p2', position: 1)
      ..cardTapped(section: HomeSection.stats);

    expect(service.eventNames, List.filled(3, AnalyticsEvents.homeCardTapped));
    expect(service.events[0].properties, {
      'section': 'featured_plan',
      'target_id': 's1',
    });
    expect(service.events[1].properties, {
      'section': 'poems',
      'target_id': 'p2',
      'position': 1,
    });
    expect(service.events[2].properties, {'section': 'stats'});
  });

  test('verse likes and comments have their own events', () {
    final service = RecordingAnalyticsService();
    HomeAnalytics(service)
      ..verseLikeChanged(verseId: 'v1', liked: true)
      ..verseLikeChanged(verseId: 'v1', liked: false)
      ..verseCommentPosted(verseId: 'v1', isReply: true);

    expect(service.eventNames, [
      AnalyticsEvents.verseLiked,
      AnalyticsEvents.verseUnliked,
      AnalyticsEvents.verseCommentPosted,
    ]);
    expect(service.events.last.properties, {'verse_id': 'v1', 'is_reply': true});
  });

  test('homeViewed carries routine, streak and guest state', () {
    final service = RecordingAnalyticsService();
    HomeAnalytics(service).homeViewed(
      hasRoutine: true,
      streakCurrent: null,
      isGuest: false,
    );

    expect(service.eventNames, [AnalyticsEvents.homeViewed]);
    expect(service.events.single.properties, {
      'has_routine': true,
      'streak_current': null,
      'is_guest': false,
    });
  });

  test('tabViewed names the tab', () {
    final service = RecordingAnalyticsService();
    HomeAnalytics(service).tabViewed(tab: 'connect');

    expect(service.eventNames, [AnalyticsEvents.tabViewed]);
    expect(service.events.single.properties, {'tab': 'connect'});
  });
}
