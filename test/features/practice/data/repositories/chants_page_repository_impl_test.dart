import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/practice/data/datasource/my_recitation_collections_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/datasource/space_chant_books_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/datasource/text_requests_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/models/my_recitation_collection_models.dart';
import 'package:flutter_pecha/features/practice/data/repositories/chants_page_repository_impl.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCollections extends Fake
    implements MyRecitationCollectionsRemoteDatasource {
  _FakeCollections(this.response);

  final Object response;
  final calls = <Map<String, Object?>>[];

  @override
  Future<MyRecitationCollectionsPageResponse> fetchCollections({
    int skip = 0,
    int limit = 20,
    RecitationCollectionScope? scope,
    String? search,
  }) async {
    calls.add({'skip': skip, 'limit': limit, 'scope': scope, 'search': search});
    final r = response;
    if (r is Exception) throw r;
    return r as MyRecitationCollectionsPageResponse;
  }
}

class _FakeSpaces extends Fake implements SpaceChantBooksRemoteDatasource {
  _FakeSpaces(this.pages);

  /// Served in order, one per call: a [GroupPracticesPage] or an error to
  /// throw.
  final List<Object> pages;
  final calls = <Map<String, Object?>>[];

  /// Book details by id: a [GroupRecitationCollection] or an error.
  final Map<String, Object> details = {};
  final detailCalls = <String>[];

  /// Detail reads in flight now, and the most seen at once.
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<GroupPracticesPage> fetchChantBooks({
    required SpaceMembership membership,
    required String language,
    required int skip,
    required int limit,
    String? search,
  }) async {
    calls.add({
      'membership': membership,
      'language': language,
      'skip': skip,
      'limit': limit,
    });
    final page = pages[calls.length - 1];
    if (page is Exception) throw page;
    return page as GroupPracticesPage;
  }

  @override
  Future<GroupRecitationCollection> fetchChantBookDetail(
    String collectionId,
  ) async {
    detailCalls.add(collectionId);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await Future<void>.delayed(Duration.zero);
    inFlight--;
    final detail = details[collectionId];
    if (detail is Exception) throw detail;
    return detail! as GroupRecitationCollection;
  }
}

class _FakeTextRequests extends Fake implements TextRequestsRemoteDatasource {
  _FakeTextRequests([this.error]);

  final Exception? error;
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> create({required String query, String? language}) async {
    calls.add({'query': query, 'language': language});
    final e = error;
    if (e != null) throw e;
  }
}

GroupPractice _collection(
  String id, {
  bool joined = false,
  String group = 'Sangha',
  int audio = 0,
}) {
  return GroupPractice(
    type: GroupPracticeType.collection,
    isJoined: joined,
    groupId: 'g-$group',
    groupName: group,
    groupAvatarUrl: 'https://cdn/$group.webp',
    collection: GroupRecitationCollection(
      id: id,
      groupId: 'g-$group',
      name: 'Book $id',
      imageUrl: 'https://cdn/$id.webp',
      itemCount: 6,
      audioItemCount: audio,
    ),
  );
}

const _accumulator = GroupPractice(type: GroupPracticeType.accumulator);

GroupPracticesPage _page(List<GroupPractice> practices, {int? total}) =>
    GroupPracticesPage(
      practices: practices,
      total: total ?? practices.length,
      skip: 0,
      limit: 100,
    );

ChantsPageRepositoryImpl _repo({
  Object? collections,
  List<Object> feed = const [],
}) => ChantsPageRepositoryImpl(
  collections: _FakeCollections(
    collections ??
        const MyRecitationCollectionsPageResponse(
          collections: [],
          skip: 0,
          limit: 20,
          total: 0,
        ),
  ),
  spaces: _FakeSpaces(feed),
  textRequests: _FakeTextRequests(),
);

void main() {
  group('splitSpaceChantBooks', () {
    test('keeps collections only and splits them by joined space', () {
      final books = splitSpaceChantBooks([
        _collection('a', joined: true, group: 'Mine'),
        _accumulator,
        _collection('b', group: 'Theirs', audio: 2),
        const GroupPractice(type: GroupPracticeType.collection),
      ]);

      expect(books.yours.map((b) => b.id), ['a']);
      expect(books.others.map((b) => b.id), ['b']);
      expect(books.hasYourSpaces, isTrue);

      final b = books.others.single;
      expect(b.source, ChantBookSource.space);
      expect(b.name, 'Book b');
      expect(b.subtitle, 'Theirs');
      expect(b.groupId, 'g-Theirs');
      expect(b.groupAvatarUrl, 'https://cdn/Theirs.webp');
      expect(b.chantCount, 6);
      expect(b.hasAudio, isTrue);
      expect(b.isJoinedSpace, isFalse);
    });

    test('lists a collection twice only once, under the joined space', () {
      final books = splitSpaceChantBooks([
        _collection('a', group: 'Theirs'),
        _collection('a', joined: true, group: 'Mine'),
      ]);
      expect(books.others, isEmpty);
      expect(books.yours.single.subtitle, 'Mine');
    });

    test('a user with no joined space books gets the new-user layout', () {
      final books = splitSpaceChantBooks([_collection('a')]);
      expect(books.hasYourSpaces, isFalse);
      expect(books.others, hasLength(1));
    });
  });

  group('getSpaceChantBooks', () {
    test('reads every space chant book in pages of 100', () async {
      final spaces = _FakeSpaces([
        GroupPracticesPage(
          practices: List.generate(100, (i) => _collection('a$i')),
          total: 101,
          skip: 0,
          limit: 100,
        ),
        GroupPracticesPage(
          practices: [_collection('last', joined: true)],
          total: 101,
          skip: 100,
          limit: 100,
        ),
      ]);
      final repo = ChantsPageRepositoryImpl(
        collections: _FakeCollections(Exception('unused')),
        spaces: spaces,
        textRequests: _FakeTextRequests(),
      );

      final result = await repo.getSpaceChantBooks(language: 'bo');

      final books = result.getOrElse((_) => SpaceChantBooks.empty);
      expect(books.others, hasLength(100));
      expect(books.yours.single.id, 'last');
      expect(spaces.calls, [
        {
          'membership': SpaceMembership.all,
          'language': 'bo',
          'skip': 0,
          'limit': 100,
        },
        {
          'membership': SpaceMembership.all,
          'language': 'bo',
          'skip': 100,
          'limit': 100,
        },
      ]);
    });

    test('fails when the first page fails', () async {
      final repo = _repo(feed: [const NetworkException('offline')]);
      final result = await repo.getSpaceChantBooks(language: 'en');
      expect(result.isLeft(), isTrue);
    });

    test('keeps what it read when a later page fails', () async {
      final repo = _repo(
        feed: [
          _page([_collection('a')], total: 300),
          const ServerException('boom'),
        ],
      );
      final result = await repo.getSpaceChantBooks(language: 'en');
      final books = result.getOrElse((_) => SpaceChantBooks.empty);
      expect(books.others, hasLength(1));
    });

    test('stops on an empty page even if total says more', () async {
      final spaces = _FakeSpaces([_page(const [], total: 50)]);
      final repo = ChantsPageRepositoryImpl(
        collections: _FakeCollections(Exception('unused')),
        spaces: spaces,
        textRequests: _FakeTextRequests(),
      );
      await repo.getSpaceChantBooks(language: 'en');
      expect(spaces.calls, hasLength(1));
    });
  });

  group('getMyChantBooks', () {
    test('asks for own and imported books and maps them to cards', () async {
      final collections = _FakeCollections(
        MyRecitationCollectionsPageResponse.fromJson({
          'collections': [
            {
              'id': 'mine',
              'name': 'Retreat Book',
              'img_url': 'https://cdn/r.webp',
              'item_count': 24,
            },
            {
              'id': 'imported',
              'name': 'Evening Practice',
              'item_count': 9,
              'audio_item_count': 3,
              'reference': {
                'id': 'src',
                'source_type': 'GROUP',
                'owner': {'name': 'Tuesday Group'},
                'imported_at': '2026-11-01T00:00:00Z',
              },
            },
          ],
          'skip': 0,
          'limit': 20,
          'total': 21,
        }),
      );
      final repo = ChantsPageRepositoryImpl(
        collections: collections,
        spaces: _FakeSpaces(const []),
        textRequests: _FakeTextRequests(),
      );

      final result = await repo.getMyChantBooks(search: 'eve');

      expect(collections.calls.single, {
        'skip': 0,
        'limit': 20,
        'scope': RecitationCollectionScope.withImports,
        'search': 'eve',
      });
      final page = result.getOrElse((_) => ChantBooksPage.empty);
      expect(page.hasMore, isTrue);
      expect(page.books.first.subtitle, isNull);
      expect(page.books.first.chantCount, 24);
      expect(page.books.first.source, ChantBookSource.personal);
      expect(page.books.last.subtitle, 'Tuesday Group');
      expect(page.books.last.hasAudio, isTrue);
    });

    test('maps a thrown error to a failure', () async {
      final repo = _repo(collections: const NetworkException('offline'));
      final result = await repo.getMyChantBooks();
      expect(result.isLeft(), isTrue);
    });
  });

  group('requestText', () {
    test('sends the query and language', () async {
      final requests = _FakeTextRequests();
      final repo = ChantsPageRepositoryImpl(
        collections: _FakeCollections(Exception('unused')),
        spaces: _FakeSpaces(const []),
        textRequests: requests,
      );
      final result = await repo.requestText(
        query: 'Heart Sutra',
        language: 'bo',
      );
      expect(result.isRight(), isTrue);
      expect(requests.calls.single, {'query': 'Heart Sutra', 'language': 'bo'});
    });

    test('a 429 becomes a rate-limit failure', () async {
      final repo = ChantsPageRepositoryImpl(
        collections: _FakeCollections(Exception('unused')),
        spaces: _FakeSpaces(const []),
        textRequests: _FakeTextRequests(const RateLimitException('slow down')),
      );
      final result = await repo.requestText(query: 'Heart Sutra');
      expect(result.getLeft().toNullable(), isA<RateLimitFailure>());
    });
  });
  group('getSpaceChants', () {
    const audio = [
      GroupRecitationAudio(
        id: 'a',
        title: 'Tara',
        assetUrl: 'https://cdn/a.mp3',
      ),
    ];
    GroupRecitationCollectionItem item(
      String textId, {
      bool withAudio = false,
      String? audioUrl,
    }) => GroupRecitationCollectionItem(
      id: 'i-$textId',
      textId: textId,
      title: 'Chant $textId',
      language: 'bo',
      type: '',
      displayOrder: 0,
      audio:
          audioUrl != null
              ? [
                GroupRecitationAudio(
                  id: audioUrl,
                  title: '',
                  assetUrl: audioUrl,
                ),
              ]
              : withAudio
              ? audio
              : const [],
    );
    GroupRecitationCollection detail(
      String id,
      List<GroupRecitationCollectionItem> items,
    ) => GroupRecitationCollection(
      id: id,
      groupId: 'g',
      name: 'Book $id',
      itemCount: items.length,
      items: items,
    );
    ChantBook book(String id, {bool joined = false, int chants = 2}) =>
        ChantBook(
          id: id,
          name: 'Book $id',
          source: ChantBookSource.space,
          chantCount: chants,
          subtitle: joined ? 'Mine' : 'Theirs',
          isJoinedSpace: joined,
        );
    List<String> ids(List<SpaceChant> chants) =>
        chants.map((c) => c.item.textId).toList();

    test('splits chants by joined space and audio, in book order', () async {
      final spaces = _FakeSpaces(const []);
      spaces.details['y'] = detail('y', [
        item('t1', withAudio: true),
        item('t2'),
      ]);
      spaces.details['o'] = detail('o', [
        item('t3'),
        item('t4', withAudio: true),
      ]);
      final repo = ChantsPageRepositoryImpl(
        collections: _FakeCollections(Exception('unused')),
        spaces: spaces,
        textRequests: _FakeTextRequests(),
      );
      final result = await repo.getSpaceChants(
        SpaceChantBooks(yours: [book('y', joined: true)], others: [book('o')]),
      );
      final chants = result.getRight().toNullable()!;
      expect(ids(chants.yoursAudio), ['t1']);
      expect(ids(chants.yoursText), ['t2']);
      expect(ids(chants.othersAudio), ['t4']);
      expect(ids(chants.othersText), ['t3']);
      expect(chants.yoursText.single.spaceName, 'Mine');
      expect(chants.othersText.single.collection.id, 'o');
    });

    test(
      'skips empty books and lists a shared text once, joined first',
      () async {
        final spaces = _FakeSpaces(const []);
        spaces.details['y'] = detail('y', [item('t1')]);
        spaces.details['o'] = detail('o', [item('t1'), item('t2')]);
        final repo = ChantsPageRepositoryImpl(
          collections: _FakeCollections(Exception('unused')),
          spaces: spaces,
          textRequests: _FakeTextRequests(),
        );
        final result = await repo.getSpaceChants(
          SpaceChantBooks(
            yours: [book('y', joined: true)],
            others: [book('o'), book('empty', chants: 0)],
          ),
        );
        final chants = result.getRight().toNullable()!;
        expect(spaces.detailCalls, ['y', 'o']);
        expect(ids(chants.yoursText), ['t1']);
        expect(ids(chants.othersText), ['t2']);
      },
    );

    test('keeps a recording when a joined book has the text only', () {
      final chants = splitSpaceChants(
        [book('y', joined: true), book('o')],
        [
          detail('y', [item('t1'), item('t2')]),
          detail('o', [item('t1', withAudio: true)]),
        ],
      );
      expect(ids(chants.othersAudio), ['t1']);
      // The text-only copy would repeat what the audio row already opens.
      expect(ids(chants.yoursText), ['t2']);
    });

    test('keeps distinct recordings of a text, the same one once', () {
      final chants = splitSpaceChants(
        [book('y', joined: true), book('o'), book('p')],
        [
          detail('y', [item('t1', audioUrl: 'https://cdn/a.mp3')]),
          detail('o', [item('t1', audioUrl: 'https://cdn/b.mp3')]),
          detail('p', [item('t1', audioUrl: 'https://cdn/a.mp3')]),
        ],
      );
      expect(chants.yoursAudio.single.collection.id, 'y');
      expect(chants.othersAudio.single.collection.id, 'o');
    });

    test('leaves out a book that fails, fails only when all do', () async {
      final spaces = _FakeSpaces(const []);
      spaces.details['a'] = detail('a', [item('t1')]);
      spaces.details['b'] = const ServerException('down');
      final repo = ChantsPageRepositoryImpl(
        collections: _FakeCollections(Exception('unused')),
        spaces: spaces,
        textRequests: _FakeTextRequests(),
      );
      final some = await repo.getSpaceChants(
        SpaceChantBooks(others: [book('a'), book('b')]),
      );
      expect(ids(some.getRight().toNullable()!.othersText), ['t1']);

      final none = await repo.getSpaceChants(
        SpaceChantBooks(others: [book('b')]),
      );
      expect(none.isLeft(), isTrue);
    });

    test('reads every book, at most detailConcurrency at once', () async {
      final spaces = _FakeSpaces(const []);
      final many = [for (var i = 0; i < 25; i++) book('b$i')];
      for (final b in many) {
        spaces.details[b.id] = detail(b.id, [item('t-${b.id}')]);
      }
      final repo = ChantsPageRepositoryImpl(
        collections: _FakeCollections(Exception('unused')),
        spaces: spaces,
        textRequests: _FakeTextRequests(),
      );
      final result = await repo.getSpaceChants(SpaceChantBooks(others: many));
      expect(result.getRight().toNullable()!.othersText, hasLength(25));
      expect(spaces.detailCalls, hasLength(25));
      expect(spaces.maxInFlight, ChantsPageRepositoryImpl.detailConcurrency);
    });

    test('reads nothing when there are no books', () async {
      final spaces = _FakeSpaces(const []);
      final repo = ChantsPageRepositoryImpl(
        collections: _FakeCollections(Exception('unused')),
        spaces: spaces,
        textRequests: _FakeTextRequests(),
      );
      final result = await repo.getSpaceChants(SpaceChantBooks.empty);
      expect(result.getRight().toNullable(), SpaceChants.empty);
      expect(spaces.detailCalls, isEmpty);
    });
  });
}
