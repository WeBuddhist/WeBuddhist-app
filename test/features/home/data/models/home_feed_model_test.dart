import 'package:flutter_pecha/features/connect/domain/entities/connect_feed_item.dart';
import 'package:flutter_pecha/features/home/data/models/home_feed_model.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// A spaces-feed row as v2 serves it (`AuthorGroupFeedItemDTO`).
Map<String, dynamic> _postRow({String id = 'p1'}) => {
  'type': 'post',
  'feed_at': '2026-11-20T10:00:00Z',
  'is_joined': true,
  'can_view_linked_content': true,
  'space_id': 'space-1',
  'space_name': 'Sherab Ling',
  'space_slug': 'sherab-ling',
  'space_avatar_url': 'https://cdn.example/avatar.png',
  'post': {
    'id': id,
    'space_id': 'space-1',
    'space_name': 'Sherab Ling',
    'space_avatar_url': 'https://cdn.example/avatar.png',
    'caption': 'A special prayer offering',
    'status': 'PUBLISHED',
    'published_at': '2026-11-20T10:00:00Z',
    'media': [
      {
        'id': 'm1',
        'media_type': 'IMAGE',
        'url': 'https://cdn.example/1.jpg',
        'display_order': 0,
      },
    ],
    'links': <Object>[],
    'creator_name': 'Admin',
    'like_count': 6,
    'comment_count': 2,
    'created_at': '2026-11-20T09:00:00Z',
    'liked_by_me': true,
  },
  'event': null,
};

Map<String, dynamic> _eventRow({String id = 'e1'}) => {
  'type': 'event',
  'feed_at': '2026-11-21T10:00:00Z',
  'is_joined': false,
  'space_id': 'space-2',
  'space_name': 'Vajrasattva Foundation',
  'space_slug': 'vajrasattva',
  'space_avatar_url': null,
  'post': null,
  'event': {
    'id': id,
    'space_id': 'space-2',
    'space_name': 'Vajrasattva Foundation',
    'space_recitation_collection_id': 'rc-1',
    'location_id': 'loc-1',
    'location': {'id': 'loc-1', 'space_id': 'space-2', 'name': 'Delhi'},
    'start_date': '2026-07-01T00:00:00Z',
    'end_date': '2026-09-30T00:00:00Z',
    'is_one_day': false,
    'event_format': 'hybrid',
    'metadata': {
      'id': 'md-1',
      'name': 'Wednesday group practice',
      'description': null,
      'language': 'EN',
    },
    'youtube': <Object>[],
    'links': <Object>[],
    'participant_count': 12,
  },
};

void main() {
  group('parseMemberPage', () {
    test('keeps posts and events, mapping space fields to group ones', () {
      final page = HomeFeedModel.parseMemberPage({
        'items': [
          {'type': 'event', 'id': 'card-1', 'content': _eventRow()},
          {'type': 'post', 'id': 'card-2', 'content': _postRow()},
        ],
        'next_cursor': 'abc',
      }, language: 'en');

      expect(page.items.map((i) => i.type), [
        ConnectFeedItemType.event,
        ConnectFeedItemType.post,
      ]);

      final event = page.items[0];
      expect(event.groupId, 'space-2');
      expect(event.groupName, 'Vajrasattva Foundation');
      expect(event.groupSlug, 'vajrasattva');
      expect(event.event!.id, 'e1');
      expect(event.event!.groupId, 'space-2');
      expect(event.event!.title, 'Wednesday group practice');
      expect(event.event!.groupRecitationCollectionId, 'rc-1');
      expect(event.event!.location!.groupId, 'space-2');

      final post = page.items[1];
      expect(post.groupId, 'space-1');
      expect(post.isJoined, isTrue);
      expect(post.groupAvatarUrl, 'https://cdn.example/avatar.png');
      expect(post.post!.groupId, 'space-1');
      expect(post.post!.groupName, 'Sherab Ling');
      expect(post.post!.likeCount, 6);
      expect(post.post!.likedByMe, isTrue);
      expect(post.post!.media.single.url, 'https://cdn.example/1.jpg');

      expect(page.next, const HomeFeedCursor('abc'));
      expect(page.hasMore, isTrue);
    });

    test('skips suggestion cards and types it does not know', () {
      final page = HomeFeedModel.parseMemberPage({
        'items': [
          {'type': 'suggested_spaces', 'id': 's', 'spaces': <Object>[]},
          {'type': 'suggested_plans', 'id': 'sp', 'plans': <Object>[]},
          {'type': 'suggested_post', 'id': 'spost', 'content': _postRow()},
          {'type': 'poll', 'id': 'x', 'content': _postRow(id: 'p9')},
          {'type': 'post', 'id': 'card', 'content': _postRow(id: 'p2')},
        ],
      }, language: 'en');

      expect(page.items.single.post!.id, 'p2');
    });

    test('drops rows with no content or an empty payload', () {
      final page = HomeFeedModel.parseMemberPage({
        'items': [
          {'type': 'post', 'id': 'a'},
          {'type': 'post', 'id': 'b', 'content': null},
          {'type': 'post', 'id': 'c', 'content': {..._postRow(), 'post': null}},
          {
            'type': 'event',
            'id': 'd',
            'content': {..._eventRow(), 'event': null},
          },
          'not a map',
        ],
      }, language: 'en');

      expect(page.items, isEmpty);
    });

    test('no or empty next_cursor is the last page', () {
      for (final cursor in [null, '']) {
        final page = HomeFeedModel.parseMemberPage({
          'items': <Object>[],
          'next_cursor': cursor,
        }, language: 'en');
        expect(page.next, isNull);
        expect(page.hasMore, isFalse);
      }
      expect(
        HomeFeedModel.parseMemberPage(const {}, language: 'en').items,
        isEmpty,
      );
    });
  });

  group('parsePublicPage', () {
    test('reads rows and offers the next offset', () {
      final page = HomeFeedModel.parsePublicPage({
        'items': [_postRow(), _eventRow()],
        'skip': 20,
        'limit': 20,
        'total': 45,
      }, language: 'en');

      expect(page.items.map((i) => i.post?.id ?? i.event?.id), ['p1', 'e1']);
      expect(page.items.first.post!.groupName, 'Sherab Ling');
      expect(page.next, const HomeFeedOffset(22));
    });

    test('counts dropped rows toward the next offset', () {
      final page = HomeFeedModel.parsePublicPage({
        'items': [
          _postRow(),
          {..._postRow(id: 'p2'), 'post': null},
          {'type': 'practice', 'space_id': 'space-3'},
        ],
        'skip': 0,
        'total': 10,
      }, language: 'en');

      expect(page.items, hasLength(1));
      expect(page.next, const HomeFeedOffset(3));
    });

    test('the last page, or an empty one, has no next', () {
      final last = HomeFeedModel.parsePublicPage({
        'items': [_postRow()],
        'skip': 23,
        'total': 24,
      }, language: 'en');
      expect(last.next, isNull);

      final empty = HomeFeedModel.parsePublicPage({
        'items': <Object>[],
        'skip': 0,
        'total': 5,
      }, language: 'en');
      expect(empty.next, isNull);
    });
  });

  group('withGroupKeys', () {
    test('copies space keys at every depth and keeps group keys sent', () {
      final out = HomeFeedModel.withGroupKeys({
        'space_id': 's',
        'group_name': 'kept',
        'space_name': 'ignored',
        'nested': {'space_slug': 'slug'},
        'list': [
          {'space_avatar_url': 'a'},
          1,
        ],
        'spaceless': 'x',
      });

      expect(out['group_id'], 's');
      expect(out['space_id'], 's');
      expect(out['group_name'], 'kept');
      expect((out['nested'] as Map)['group_slug'], 'slug');
      expect(((out['list'] as List).first as Map)['group_avatar_url'], 'a');
      expect((out['list'] as List)[1], 1);
      expect(out.containsKey('group_less'), isFalse);
    });
  });
}
