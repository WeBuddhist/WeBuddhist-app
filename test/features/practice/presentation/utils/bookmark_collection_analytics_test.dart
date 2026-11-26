import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/features/practice/data/datasource/bookmark_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/presentation/controllers/bookmark_controller.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/practice_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService service;
  late PracticeAnalytics analytics;

  setUp(() {
    service = RecordingAnalyticsService();
    analytics = PracticeAnalytics(service);
  });

  test('bookmarks are added and removed with their type', () {
    analytics.bookmarkChanged(added: true, itemType: 'text', itemId: 't1');
    analytics.bookmarkChanged(added: false, itemType: 'mala', itemId: 'm1');
    analytics.bookmarksOpened();

    expect(service.eventNames, [
      AnalyticsEvents.bookmarkAdded,
      AnalyticsEvents.bookmarkRemoved,
      AnalyticsEvents.bookmarksOpened,
    ]);
    expect(service.events.first.properties, {
      'item_type': 'text',
      'item_id': 't1',
    });
  });

  test('bookmark types become snake_case keys', () {
    expect(bookmarkTypeKey(BookmarkType.text), 'text');
    expect(bookmarkTypeKey(BookmarkType.accumulator), 'mala');
    expect(
      bookmarkTypeKey(BookmarkType.groupRecitationCollection),
      'group_recitation_collection',
    );
    expect(bookmarkTypeKey(BookmarkType.groupAccumulator), 'group_accumulator');
  });

  test('collections send counts only, no names', () {
    analytics.collectionCreated(
      collectionId: 'c1',
      itemCount: 4,
      hasImage: true,
    );
    analytics.collectionUpdated(
      collectionId: 'c1',
      itemCount: 5,
      itemsAdded: 2,
      itemsRemoved: 1,
      reordered: true,
      renamed: false,
      imageChanged: false,
    );
    analytics.collectionDeleted(collectionId: 'c1');

    expect(service.eventNames, [
      AnalyticsEvents.collectionCreated,
      AnalyticsEvents.collectionUpdated,
      AnalyticsEvents.collectionDeleted,
    ]);
    expect(service.events[0].properties, {
      'collection_id': 'c1',
      'item_count': 4,
      'has_image': true,
    });
    expect(service.events[1].properties, {
      'collection_id': 'c1',
      'item_count': 5,
      'items_added': 2,
      'items_removed': 1,
      'reordered': true,
      'renamed': false,
      'image_changed': false,
    });
  });
}
