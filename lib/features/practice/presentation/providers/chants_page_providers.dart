import 'dart:async';

import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/practice/data/datasource/space_chant_books_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/datasource/text_requests_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/repositories/chants_page_repository_impl.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/domain/repositories/chants_page_repository.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/my_recitation_collections_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_sections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

final chantsPageRepositoryProvider = Provider<ChantsPageRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ChantsPageRepositoryImpl(
    collections: ref.watch(myRecitationCollectionsRemoteDatasourceProvider),
    spaces: SpaceChantBooksRemoteDatasource(dio: dio),
    textRequests: TextRequestsRemoteDatasource(dio: dio),
  );
});

/// Chant books shown in a rail before "See all".
const int chantsPageRailLimit = 20;

/// First page of the user's chant books for the "My chantbooks" rail.
/// Guests and signed-out users have none, so nothing is requested.
final myChantBooksProvider =
    FutureProvider.autoDispose<Either<Failure, ChantBooksPage>>((ref) {
      final auth = ref.watch(authProvider);
      if (auth.isGuest || !auth.isLoggedIn) {
        return const Right(ChantBooksPage.empty);
      }
      return ref
          .watch(chantsPageRepositoryProvider)
          .getMyChantBooks(limit: chantsPageRailLimit);
    });

/// How long loaded space books and chants outlive the last screen showing
/// them. Reading them is one feed read plus one detail read per book, so
/// leaving the Chants page and coming back should not repeat it. Pull to
/// refresh, a language change and a sign-in change still read again.
const Duration spaceChantsCacheTime = Duration(minutes: 5);

extension CacheSuccessFor on Ref<Object?> {
  /// Awaits [load], then keeps this provider for [duration] after nothing
  /// listens, only when it succeeded, so a failure is retried on the next
  /// visit. The provider is held while [load] runs, so leaving mid-load
  /// does not throw the read away.
  Future<Either<Failure, T>> cacheSuccessFor<T>(
    Future<Either<Failure, T>> load,
    Duration duration,
  ) async {
    // Taken before the await: the ref may be rebuilt while it runs.
    final link = keepAlive();
    Timer? timer;
    onDispose(() => timer?.cancel());
    final result = await load;
    if (result.isLeft()) {
      link.close();
    } else {
      timer = Timer(duration, link.close);
    }
    return result;
  }
}

/// Space chant books, split into the user's spaces and the rest. Re-read
/// when sign-in changes, since that changes which spaces count as joined.
final spaceChantBooksProvider =
    FutureProvider.autoDispose<Either<Failure, SpaceChantBooks>>((ref) {
      ref.watch(authProvider.select((auth) => auth.isLoggedIn));
      final language = ref.watch(contentLanguageProvider);
      return ref.cacheSuccessFor(
        ref
            .watch(chantsPageRepositoryProvider)
            .getSpaceChantBooks(language: language),
        spaceChantsCacheTime,
      );
    });

/// Every chant inside the space chant books, split by joined space and by
/// audio, in all languages. Follows [spaceChantBooksProvider]; a failed
/// book list fails this too, so the page shows one error.
final allSpaceChantsProvider =
    FutureProvider.autoDispose<Either<Failure, SpaceChants>>((ref) async {
      final books = await ref.watch(spaceChantBooksProvider.future);
      return ref.cacheSuccessFor(
        books.fold(
          (failure) async => Left<Failure, SpaceChants>(failure),
          (books) =>
              ref.read(chantsPageRepositoryProvider).getSpaceChants(books),
        ),
        spaceChantsCacheTime,
      );
    });

/// The space chants in the Chants page language, as its language button
/// picks. Changing the language re-filters what is loaded; nothing is
/// read again. Chant books have no language and are not filtered.
final spaceChantsProvider =
    FutureProvider.autoDispose<Either<Failure, SpaceChants>>((ref) async {
      final language = ref.watch(practiceRecitationsLanguageProvider);
      final all = await ref.watch(allSpaceChantsProvider.future);
      return all.map((chants) => chants.inLanguage(language));
    });

/// Every page of the user's chant books, for the "My chant books" See-all
/// grid. Pagination shape as in `connect_post_comments_providers.dart`.
class MyChantBooksPagedState {
  const MyChantBooksPagedState({
    this.books = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.skip = 0,
    this.total = 0,
  });

  final List<ChantBook> books;
  final bool isLoading;
  final bool isLoadingMore;
  final Failure? error;
  final bool hasMore;
  final int skip;
  final int total;

  MyChantBooksPagedState copyWith({
    List<ChantBook>? books,
    bool? isLoading,
    bool? isLoadingMore,
    Failure? error,
    bool? hasMore,
    int? skip,
    int? total,
    bool clearError = false,
  }) {
    return MyChantBooksPagedState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : error ?? this.error,
      hasMore: hasMore ?? this.hasMore,
      skip: skip ?? this.skip,
      total: total ?? this.total,
    );
  }
}

class MyChantBooksPagedNotifier extends StateNotifier<MyChantBooksPagedState> {
  MyChantBooksPagedNotifier(this._repository)
    : super(const MyChantBooksPagedState()) {
    loadInitial();
  }

  final ChantsPageRepository _repository;
  static const int pageSize = 20;

  /// Bumped by each first-page load so an older page arriving late is
  /// dropped rather than appended.
  int _epoch = 0;

  Future<void> loadInitial() async {
    final epoch = ++_epoch;
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.getMyChantBooks(limit: pageSize);
    if (!mounted || epoch != _epoch) return;
    state = result.fold(
      (failure) => state.copyWith(isLoading: false, error: failure),
      (page) => MyChantBooksPagedState(
        books: page.books,
        hasMore: page.hasMore,
        skip: page.books.length,
        total: page.total,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final epoch = _epoch;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    final result = await _repository.getMyChantBooks(
      skip: state.skip,
      limit: pageSize,
    );
    if (!mounted || epoch != _epoch) return;
    state = result.fold(
      (failure) => state.copyWith(isLoadingMore: false, error: failure),
      (page) {
        final seen = state.books.map((b) => b.id).toSet();
        final fresh = page.books.where((b) => seen.add(b.id)).toList();
        final skip = state.skip + page.books.length;
        return state.copyWith(
          books: [...state.books, ...fresh],
          isLoadingMore: false,
          skip: skip,
          total: page.total,
          // An empty page ends paging even if total says otherwise.
          hasMore: page.books.isNotEmpty && skip < page.total,
        );
      },
    );
  }

  Future<void> refresh() => loadInitial();
}

final myChantBooksPagedProvider = StateNotifierProvider.autoDispose<
  MyChantBooksPagedNotifier,
  MyChantBooksPagedState
>((ref) => MyChantBooksPagedNotifier(ref.watch(chantsPageRepositoryProvider)));

/// Chant books matching a search: the user's own (searched on the server),
/// then books from their spaces, then other spaces (matched against the
/// already-loaded feed). A book found twice is listed once.
final chantBookSearchProvider = FutureProvider.autoDispose
    .family<Either<Failure, List<ChantBook>>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.length < chantsSearchMinQueryLength) return const Right([]);

      final auth = ref.read(authProvider);
      final signedIn = auth.isLoggedIn && !auth.isGuest;
      const noBooks = Right<Failure, ChantBooksPage>(ChantBooksPage.empty);
      // 50 is the endpoint's largest page.
      final mineFuture =
          signedIn
              ? ref
                  .read(chantsPageRepositoryProvider)
                  .getMyChantBooks(search: trimmed, limit: 50)
              : Future.value(noBooks);
      final spaces = await ref.watch(spaceChantBooksProvider.future);
      final mine = await mineFuture;

      final myBooks = mine.fold((_) => const <ChantBook>[], (p) => p.books);
      final space = spaces.getOrElse((_) => SpaceChantBooks.empty);
      final seen = <String>{};
      List<ChantBook> match(List<ChantBook> books) => matchChantBooks(
        books,
        trimmed,
        name: (b) => b.name,
        subtitle: (b) => b.subtitle,
      );
      final books =
          [
            ...myBooks,
            ...match(space.yours),
            ...match(space.others),
          ].where((b) => seen.add('${b.source.name}:${b.id}')).toList();
      // What one source found is shown even if the other failed; with
      // nothing found, a failure is reported, so search can offer a retry
      // instead of "Can't find".
      if (books.isEmpty) {
        final failure =
            mine.getLeft().toNullable() ?? spaces.getLeft().toNullable();
        if (failure != null) return Left(failure);
      }
      return Right(books);
    });
