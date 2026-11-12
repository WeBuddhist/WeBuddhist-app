import 'dart:async';

import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/domain/repositories/chants_page_repository.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class _FakeRepo implements ChantsPageRepository {
  /// Replies keyed by skip; a missing key waits on [gate].
  final Map<int, Either<Failure, ChantBooksPage>> pages = {};
  final skips = <int>[];
  Completer<void>? gate;

  @override
  Future<Either<Failure, ChantBooksPage>> getMyChantBooks({
    int skip = 0,
    int limit = 20,
    String? search,
  }) async {
    skips.add(skip);
    await gate?.future;
    return pages[skip]!;
  }

  @override
  Future<Either<Failure, SpaceChantBooks>> getSpaceChantBooks({
    required String language,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, SpaceChants>> getSpaceChants(SpaceChantBooks books) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> requestText({
    required String query,
    String? language,
  }) => throw UnimplementedError();
}

List<ChantBook> _books(String prefix, int count) => [
  for (var i = 0; i < count; i++)
    ChantBook(
      id: '$prefix$i',
      name: '$prefix$i',
      source: ChantBookSource.personal,
    ),
];

void main() {
  test('loads the first page, then appends the next', () async {
    final repo =
        _FakeRepo()
          ..pages[0] = Right(
            ChantBooksPage(books: _books('a', 20), skip: 0, total: 25),
          )
          ..pages[20] = Right(
            ChantBooksPage(books: _books('b', 5), skip: 20, total: 25),
          );
    final notifier = MyChantBooksPagedNotifier(repo);
    addTearDown(notifier.dispose);
    await pumpEventQueue();

    expect(notifier.state.books, hasLength(20));
    expect(notifier.state.hasMore, isTrue);

    await notifier.loadMore();
    expect(notifier.state.books, hasLength(25));
    expect(notifier.state.hasMore, isFalse);
    expect(repo.skips, [0, 20]);

    await notifier.loadMore();
    expect(repo.skips, [0, 20], reason: 'nothing more to load');
  });

  test('an empty page ends paging even if total says more', () async {
    final repo =
        _FakeRepo()
          ..pages[0] = Right(
            ChantBooksPage(books: _books('a', 20), skip: 0, total: 99),
          )
          ..pages[20] = const Right(
            ChantBooksPage(books: [], skip: 20, total: 99),
          );
    final notifier = MyChantBooksPagedNotifier(repo);
    addTearDown(notifier.dispose);
    await pumpEventQueue();
    await notifier.loadMore();
    expect(notifier.state.hasMore, isFalse);
  });

  test('a book repeated across pages is listed once', () async {
    final repo =
        _FakeRepo()
          ..pages[0] = Right(
            ChantBooksPage(books: _books('a', 20), skip: 0, total: 40),
          )
          ..pages[20] = Right(
            ChantBooksPage(
              books: [..._books('a', 1), ..._books('b', 19)],
              skip: 20,
              total: 40,
            ),
          );
    final notifier = MyChantBooksPagedNotifier(repo);
    addTearDown(notifier.dispose);
    await pumpEventQueue();
    await notifier.loadMore();
    expect(notifier.state.books, hasLength(39));
    expect(notifier.state.skip, 40);
  });

  test('a first-page failure is kept for the retry screen', () async {
    final repo = _FakeRepo()..pages[0] = const Left(NetworkFailure('offline'));
    final notifier = MyChantBooksPagedNotifier(repo);
    addTearDown(notifier.dispose);
    await pumpEventQueue();
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, const NetworkFailure('offline'));
  });

  test('a page from before a refresh is dropped', () async {
    final repo =
        _FakeRepo()
          ..pages[0] = Right(
            ChantBooksPage(books: _books('a', 20), skip: 0, total: 40),
          )
          ..pages[20] = Right(
            ChantBooksPage(books: _books('old', 20), skip: 20, total: 40),
          );
    final notifier = MyChantBooksPagedNotifier(repo);
    addTearDown(notifier.dispose);
    await pumpEventQueue();

    repo.gate = Completer<void>();
    final more = notifier.loadMore();
    final refresh = notifier.refresh();
    repo.gate!.complete();
    await Future.wait([more, refresh]);

    final ids = notifier.state.books.map((b) => b.id);
    expect(ids, everyElement(startsWith('a')));
    expect(notifier.state.books, hasLength(20));
  });
}
