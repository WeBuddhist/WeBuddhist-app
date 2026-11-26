import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_key.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_source.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/connect/domain/entities/connect_feed_item.dart';
import 'package:flutter_pecha/features/connect/domain/entities/connect_post.dart';
import 'package:flutter_pecha/features/home/data/datasource/home_feed_remote_datasource.dart';
import 'package:flutter_pecha/features/home/data/models/home_feed_model.dart';
import 'package:flutter_pecha/features/home/data/repositories/home_feed_repository_impl.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';
import 'package:flutter_pecha/features/home/domain/repositories/home_feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('HomeFeed');

class HomeFeedState {
  final List<ConnectFeedItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// Where the next page starts; null until a page came from the server.
  final HomeFeedPageToken? next;
  final String? error;
  final bool hasLoaded;

  const HomeFeedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.next,
    this.error,
    this.hasLoaded = false,
  });

  /// Nothing more is coming without the user asking: the last page is in,
  /// or the last read failed. Poems and share then close a short feed.
  bool get feedEnded =>
      hasLoaded &&
      !isLoading &&
      !isLoadingMore &&
      (!hasMore || error != null);

  /// A next page exists and nothing is in flight or failed.
  bool get canLoadMore =>
      next != null &&
      hasMore &&
      !isLoading &&
      !isLoadingMore &&
      error == null;

  HomeFeedState copyWith({
    List<ConnectFeedItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    HomeFeedPageToken? next,
    bool clearNext = false,
    String? error,
    bool clearError = false,
    bool? hasLoaded,
  }) {
    return HomeFeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      next: clearNext ? null : next ?? this.next,
      error: clearError ? null : error ?? this.error,
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}

/// Home's posts-and-events feed: `/feed` for members, the public spaces feed
/// for guests.
///
/// The stored first page shows at once, but its cursor is never used: a
/// member's mix is fixed per cursor and an old one may have expired. Paging
/// waits for the fresh first page. New posts arrive on [refresh] only; posts
/// already shown are patched in place through [updatePost].
class HomeFeedNotifier extends StateNotifier<HomeFeedState> {
  HomeFeedNotifier({
    required HomeFeedRepository repository,
    required ScreenCacheSource<HomeFeedPage> firstPage,
    required this.signedIn,
    required this.language,
  }) : _repository = repository,
       _firstPage = firstPage,
       super(_seed(firstPage)) {
    loadInitial();
  }

  static HomeFeedState _seed(ScreenCacheSource<HomeFeedPage> firstPage) {
    final page = firstPage.read();
    if (page == null) return const HomeFeedState();
    return HomeFeedState(
      items: page.items,
      hasMore: page.hasMore,
      hasLoaded: true,
    );
  }

  final HomeFeedRepository _repository;
  final ScreenCacheSource<HomeFeedPage> _firstPage;
  final bool signedIn;
  final String language;

  /// The first-page read in flight; paging waits for it.
  Future<void>? _firstPageLoad;

  /// Bumped when page one is replaced, so a page read against the old list
  /// is dropped.
  int _epoch = 0;

  /// Reads page one, a fresh mix for members, keeping what's on screen until
  /// it lands. A second call while one is out joins it.
  Future<void> loadInitial() => _firstPageLoad ??= _loadFirstPage();

  /// Pull-to-refresh.
  Future<void> refresh() => loadInitial();

  Future<void> _loadFirstPage() async {
    _epoch++;
    state = state.copyWith(
      isLoading: state.items.isEmpty,
      isLoadingMore: false,
      clearError: true,
    );
    try {
      final result = await _firstPage.refresh();
      if (!mounted) return;
      result.fold(
        // Paging can't go on from a stored page, so the feed ends here.
        (failure) =>
            state = state.copyWith(
              isLoading: false,
              hasLoaded: true,
              hasMore: false,
              clearNext: true,
              error: failure.message,
            ),
        (page) {
          _logger.info(
            'page one: ${page.items.length} cards, more=${page.hasMore}',
          );
          state = HomeFeedState(
            items: _unique(page.items),
            hasMore: page.hasMore,
            next: page.next,
            hasLoaded: true,
          );
        },
      );
    } finally {
      _firstPageLoad = null;
    }
  }

  /// The next page, asked for as Home nears its end. After a failure it
  /// waits for [retry], so scrolling doesn't re-send the failed request.
  Future<void> loadMore() async {
    if (state.error != null) return;
    return _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    final next = state.next;
    if (next == null ||
        !state.hasMore ||
        state.isLoading ||
        state.isLoadingMore ||
        _firstPageLoad != null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);
    final epoch = _epoch;
    final result = await _repository.getFeed(
      signedIn: signedIn,
      language: language,
      after: next,
    );
    if (!mounted || epoch != _epoch) return;

    result.fold(
      (failure) =>
          state = state.copyWith(isLoadingMore: false, error: failure.message),
      (page) {
        _logger.info(
          'next page: ${page.items.length} cards, more=${page.hasMore}',
        );
        final known = {for (final item in state.items) item.dedupeKey};
        state = state.copyWith(
          items: [
            ...state.items,
            ...page.items.where((item) => known.add(item.dedupeKey)),
          ],
          isLoadingMore: false,
          hasMore: page.hasMore,
          next: page.next,
          clearNext: page.next == null,
          clearError: true,
        );
      },
    );
  }

  /// Retry after a failure: page one if nothing is shown, else the next page.
  Future<void> retry() =>
      state.items.isEmpty || state.next == null
          ? loadInitial()
          : _loadNextPage();

  /// A like, unlike or comment count changed elsewhere.
  void updatePost(ConnectPost post) {
    final index = state.items.indexWhere(
      (item) =>
          item.type == ConnectFeedItemType.post && item.post?.id == post.id,
    );
    if (index == -1) return;
    final items = [...state.items];
    items[index] = items[index].copyWithPost(post);
    state = state.copyWith(items: items);
  }

  static List<ConnectFeedItem> _unique(List<ConnectFeedItem> items) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.dedupeKey)) item,
    ];
  }
}

final homeFeedRemoteDatasourceProvider = Provider<HomeFeedRemoteDatasource>(
  (ref) => HomeFeedRemoteDatasource(dio: ref.watch(dioProvider)),
);

final homeFeedRepositoryProvider = Provider<HomeFeedRepository>(
  (ref) => HomeFeedRepositoryImpl(
    remote: ref.watch(homeFeedRemoteDatasourceProvider),
  ),
);

/// Page one of Home's feed, stored per user, language and audience.
ScreenCacheSource<HomeFeedPage> homeFeedFirstPageSource(
  Ref ref, {
  required bool signedIn,
  required String language,
}) {
  final store = ref.watch(screenCacheStoreProvider);
  final remote = ref.watch(homeFeedRemoteDatasourceProvider);
  return ScreenCacheSource<HomeFeedPage>(
    store: store,
    key: ScreenCacheKey.user(
      'home_feed',
      userId: store.currentUserIdSync,
      language: language,
      params: [signedIn ? 'member' : 'guest'],
    ),
    fetchJson:
        () =>
            signedIn
                ? remote.fetchMemberFeedJson(language: language)
                : remote.fetchPublicFeedJson(language: language),
    fromJson: (json) {
      final page = json as Map<String, dynamic>;
      return signedIn
          ? HomeFeedModel.parseMemberPage(page, language: language)
          : HomeFeedModel.parsePublicPage(page, language: language);
    },
    failureMessage: 'Failed to load feed',
  );
}

/// Lives for the session, not just while Home is on screen: `/chats` and
/// other top-level routes replace the tab shell, and coming back must not
/// throw away the pages read so far for a fresh mix. A new account or
/// language rebuilds it; pull-to-refresh asks for a fresh mix.
final homeFeedProvider =
    StateNotifierProvider<HomeFeedNotifier, HomeFeedState>((ref) {
      final language = ref.watch(contentLanguageProvider);
      final signedIn = ref.watch(
        authProvider.select((auth) => auth.isLoggedIn && !auth.isGuest),
      );
      return HomeFeedNotifier(
        repository: ref.watch(homeFeedRepositoryProvider),
        firstPage: homeFeedFirstPageSource(
          ref,
          signedIn: signedIn,
          language: language,
        ),
        signedIn: signedIn,
        language: language,
      );
    });
