import 'dart:async';
import 'dart:convert';

import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_source.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/connect/domain/entities/connect_feed_item.dart';
import 'package:flutter_pecha/features/home/data/models/home_feed_model.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';
import 'package:flutter_pecha/features/home/domain/repositories/home_feed_repository.dart';
import 'package:flutter_pecha/features/home/presentation/providers/home_feed_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../helpers/fake_screen_cache_store.dart';

const _key = 'home_feed_test';

Map<String, dynamic> _postRow(String id) => {
  'type': 'post',
  'space_id': 'space-1',
  'space_name': 'Space',
  'post': {'id': id, 'caption': 'Post $id', 'like_count': 0},
};

/// A raw `/feed` page holding posts [ids].
Map<String, dynamic> _memberJson(List<String> ids, {String? next}) => {
  'items': [
    for (final id in ids)
      {'type': 'post', 'id': 'card-$id', 'content': _postRow(id)},
  ],
  'next_cursor': next,
};

HomeFeedPage _page(List<String> ids, {String? next}) =>
    HomeFeedModel.parseMemberPage(_memberJson(ids, next: next), language: 'en');

List<String?> _ids(HomeFeedState state) =>
    state.items.map((item) => item.post?.id).toList();

/// Each `getFeed` call waits on its own completer, in call order.
class _FakeRepository implements HomeFeedRepository {
  final calls = <({bool signedIn, HomeFeedPageToken? after})>[];
  final replies = <Completer<Either<Failure, HomeFeedPage>>>[];

  @override
  Future<Either<Failure, HomeFeedPage>> getFeed({
    required bool signedIn,
    required String language,
    HomeFeedPageToken? after,
  }) {
    calls.add((signedIn: signedIn, after: after));
    final reply = Completer<Either<Failure, HomeFeedPage>>();
    replies.add(reply);
    return reply.future;
  }
}

void main() {
  late FakeScreenCacheStore store;
  late _FakeRepository repository;
  late List<Completer<Object>> firstPageReplies;

  ScreenCacheSource<HomeFeedPage> source() => ScreenCacheSource<HomeFeedPage>(
    store: store,
    key: _key,
    fetchJson: () {
      final reply = Completer<Object>();
      firstPageReplies.add(reply);
      return reply.future;
    },
    fromJson:
        (json) => HomeFeedModel.parseMemberPage(
          json as Map<String, dynamic>,
          language: 'en',
        ),
    failureMessage: 'Failed to load feed',
  );

  HomeFeedNotifier notifier({bool signedIn = true}) => HomeFeedNotifier(
    repository: repository,
    firstPage: source(),
    signedIn: signedIn,
    language: 'en',
  );

  /// Answers the oldest unanswered first-page read and lets it land.
  Future<void> answerFirstPage(Object json) async {
    firstPageReplies.firstWhere((r) => !r.isCompleted).complete(json);
    await pumpEventQueue();
  }

  Future<void> failFirstPage() async {
    firstPageReplies
        .firstWhere((r) => !r.isCompleted)
        .completeError(Exception('offline'));
    await pumpEventQueue();
  }

  Future<void> answerNext(Either<Failure, HomeFeedPage> result) async {
    repository.replies.firstWhere((r) => !r.isCompleted).complete(result);
    await pumpEventQueue();
  }

  setUp(() {
    store = FakeScreenCacheStore();
    repository = _FakeRepository();
    firstPageReplies = [];
  });

  test('with nothing stored, loads page one and stores it', () async {
    final feed = notifier();
    expect(feed.state.isLoading, isTrue);
    expect(feed.state.hasLoaded, isFalse);

    await answerFirstPage(_memberJson(['a', 'b'], next: 'c1'));

    expect(_ids(feed.state), ['a', 'b']);
    expect(feed.state.isLoading, isFalse);
    expect(feed.state.hasLoaded, isTrue);
    expect(feed.state.next, const HomeFeedCursor('c1'));
    expect(feed.state.feedEnded, isFalse);
    expect(store.entries[_key], isNotNull);
  });

  test('a stored page shows at once but never pages from its cursor', () async {
    await store.save(_key, _encode(_memberJson(['x'], next: 'old')));

    final feed = notifier();
    expect(_ids(feed.state), ['x']);
    expect(feed.state.isLoading, isFalse);
    expect(feed.state.next, isNull);

    await feed.loadMore();
    expect(repository.calls, isEmpty);

    await answerFirstPage(_memberJson(['a', 'b'], next: 'fresh'));
    expect(_ids(feed.state), ['a', 'b']);

    unawaited(feed.loadMore());
    expect(repository.calls.single.after, const HomeFeedCursor('fresh'));
  });

  test('pages on, dropping cards already shown, until the last page', () async {
    final feed = notifier();
    await answerFirstPage(_memberJson(['a', 'b'], next: 'c1'));

    unawaited(feed.loadMore());
    expect(feed.state.isLoadingMore, isTrue);
    await answerNext(Right(_page(['b', 'c'], next: 'c2')));
    expect(_ids(feed.state), ['a', 'b', 'c']);
    expect(feed.state.next, const HomeFeedCursor('c2'));

    unawaited(feed.loadMore());
    await answerNext(Right(_page(['d'])));
    expect(_ids(feed.state), ['a', 'b', 'c', 'd']);
    expect(feed.state.hasMore, isFalse);
    expect(feed.state.next, isNull);
    expect(feed.state.feedEnded, isTrue);

    await feed.loadMore();
    expect(repository.calls, hasLength(2));
    expect(repository.calls.every((call) => call.signedIn), isTrue);
  });

  test('guests page with the guest flag', () async {
    final feed = notifier(signedIn: false);
    await answerFirstPage(_memberJson(['a'], next: 'c1'));
    unawaited(feed.loadMore());
    expect(repository.calls.single.signedIn, isFalse);
  });

  test('refresh drops a page read against the old list', () async {
    final feed = notifier();
    await answerFirstPage(_memberJson(['a'], next: 'c1'));

    unawaited(feed.loadMore());
    final refreshed = feed.refresh();
    expect(feed.state.isLoadingMore, isFalse);
    expect(_ids(feed.state), ['a'], reason: 'kept on screen while refreshing');

    await answerNext(Right(_page(['stale'], next: 'c9')));
    expect(_ids(feed.state), ['a']);

    await answerFirstPage(_memberJson(['n1', 'n2'], next: 'c5'));
    await refreshed;
    expect(_ids(feed.state), ['n1', 'n2']);
    expect(feed.state.next, const HomeFeedCursor('c5'));
  });

  test('a second load while one is out joins it', () async {
    final feed = notifier();
    final again = feed.loadInitial();
    expect(firstPageReplies, hasLength(1));
    await answerFirstPage(_memberJson(['a']));
    await again;
    expect(_ids(feed.state), ['a']);
  });

  test('page one failing with nothing shown is an ended, failed feed', () async {
    final feed = notifier();
    await failFirstPage();

    expect(feed.state.items, isEmpty);
    expect(feed.state.error, isNotNull);
    expect(feed.state.hasLoaded, isTrue);
    expect(feed.state.feedEnded, isTrue);

    final retried = feed.retry();
    expect(feed.state.isLoading, isTrue);
    await answerFirstPage(_memberJson(['a'], next: 'c1'));
    await retried;
    expect(_ids(feed.state), ['a']);
    expect(feed.state.error, isNull);
  });

  test('page one failing keeps a stored page, without paging', () async {
    await store.save(_key, _encode(_memberJson(['x'], next: 'old')));
    final feed = notifier();
    await failFirstPage();

    expect(_ids(feed.state), ['x']);
    expect(feed.state.hasMore, isFalse);
    expect(feed.state.feedEnded, isTrue);
  });

  test('a failed next page can be retried from the same cursor', () async {
    final feed = notifier();
    await answerFirstPage(_memberJson(['a'], next: 'c1'));

    unawaited(feed.loadMore());
    await answerNext(const Left(NetworkFailure('offline')));
    expect(feed.state.error, 'offline');
    expect(feed.state.hasMore, isTrue);
    expect(feed.state.isLoadingMore, isFalse);
    expect(feed.state.feedEnded, isTrue);

    // Scrolling on doesn't re-send it; only Retry does.
    expect(feed.state.canLoadMore, isFalse);
    await feed.loadMore();
    expect(repository.calls, hasLength(1));

    unawaited(feed.retry());
    expect(feed.state.error, isNull);
    expect(repository.calls.map((call) => call.after), [
      const HomeFeedCursor('c1'),
      const HomeFeedCursor('c1'),
    ]);
    await answerNext(Right(_page(['b'])));
    expect(_ids(feed.state), ['a', 'b']);
    expect(feed.state.error, isNull);
  });

  test('updatePost patches a shown post and ignores others', () async {
    final feed = notifier();
    await answerFirstPage(_memberJson(['a', 'b']));

    final post = feed.state.items[1].post!;
    feed.updatePost(post.copyWith(likeCount: 7, likedByMe: true));
    expect(feed.state.items[1].post!.likeCount, 7);
    expect(feed.state.items[1].post!.likedByMe, isTrue);
    expect(feed.state.items[1].type, ConnectFeedItemType.post);

    final before = feed.state;
    feed.updatePost(_page(['zzz']).items.single.post!);
    expect(feed.state, same(before));
  });
}

String _encode(Map<String, dynamic> json) => jsonEncode(json);
