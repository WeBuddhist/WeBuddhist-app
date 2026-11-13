import 'dart:math';

import 'package:flutter_pecha/core/error/exception_mapper.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/practice/data/datasource/my_recitation_collections_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/datasource/space_chant_books_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/datasource/text_requests_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/models/my_recitation_collection_models.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/domain/repositories/chants_page_repository.dart';
import 'package:fpdart/fpdart.dart';

class ChantsPageRepositoryImpl implements ChantsPageRepository {
  ChantsPageRepositoryImpl({
    required MyRecitationCollectionsRemoteDatasource collections,
    required SpaceChantBooksRemoteDatasource spaces,
    required TextRequestsRemoteDatasource textRequests,
  }) : _collections = collections,
       _spaces = spaces,
       _textRequests = textRequests;

  final MyRecitationCollectionsRemoteDatasource _collections;
  final SpaceChantBooksRemoteDatasource _spaces;
  final TextRequestsRemoteDatasource _textRequests;

  /// Largest page the practices feed serves.
  static const int feedPageSize = 100;

  /// Feed pages read at most: 500 chant books. Joined and other spaces come
  /// in one list (`membership=all`) and are split on `is_joined` here, so
  /// both sections fill from the same read; on 2026-11-11 a guest's list
  /// held 10 chant books.
  static const int maxFeedPages = 5;

  @override
  Future<Either<Failure, ChantBooksPage>> getMyChantBooks({
    int skip = 0,
    int limit = 20,
    String? search,
  }) async {
    try {
      final page = await _collections.fetchCollections(
        skip: skip,
        limit: limit,
        scope: RecitationCollectionScope.withImports,
        search: search,
      );
      return Right(
        ChantBooksPage(
          books: page.collections.map(chantBookFromPersonal).toList(),
          skip: page.skip,
          total: page.total,
        ),
      );
    } catch (e) {
      return Left(ExceptionMapper.map(e, context: 'getMyChantBooks'));
    }
  }

  @override
  Future<Either<Failure, SpaceChantBooks>> getSpaceChantBooks({
    required String language,
  }) async {
    final practices = <GroupPractice>[];
    var skip = 0;
    var isPartial = false;
    for (var i = 0; i < maxFeedPages; i++) {
      final GroupPracticesPage page;
      try {
        page = await _spaces.fetchChantBooks(
          membership: SpaceMembership.all,
          language: language,
          skip: skip,
          limit: feedPageSize,
        );
      } catch (e) {
        // A later page failing still shows what was read, marked as cut
        // short so the page can say so; a first one fails.
        if (practices.isEmpty) {
          return Left(ExceptionMapper.map(e, context: 'getSpaceChantBooks'));
        }
        isPartial = true;
        break;
      }
      practices.addAll(page.practices);
      skip += page.practices.length;
      if (!page.hasMore || page.practices.isEmpty) break;
    }
    return Right(splitSpaceChantBooks(practices, isPartial: isPartial));
  }

  /// Book details read at the same time. On 2026-11-12 each took ~3 s and
  /// the feed held 10 books, so they all go at once.
  static const int detailConcurrency = 10;

  @override
  Future<Either<Failure, SpaceChants>> getSpaceChants(
    SpaceChantBooks books,
  ) async {
    final wanted =
        [
          ...books.yours,
          ...books.others,
        ].where((book) => book.chantCount > 0).toList();
    if (wanted.isEmpty) return const Right(SpaceChants.empty);

    final details = List<GroupRecitationCollection?>.filled(
      wanted.length,
      null,
    );
    Object? firstError;
    // A pool, not batches: each worker takes the next book as soon as its
    // last one lands, so one slow book holds up no others.
    var next = 0;
    Future<void> worker() async {
      while (next < wanted.length) {
        final i = next++;
        try {
          details[i] = await _spaces.fetchChantBookDetail(wanted[i].id);
        } catch (e) {
          firstError ??= e;
        }
      }
    }

    await Future.wait([
      for (var w = 0; w < min(detailConcurrency, wanted.length); w++) worker(),
    ]);
    if (details.every((detail) => detail == null)) {
      return Left(
        ExceptionMapper.map(
          firstError ?? StateError('No chant book loaded'),
          context: 'getSpaceChants',
        ),
      );
    }
    return Right(splitSpaceChants(wanted, details));
  }

  @override
  Future<Either<Failure, Unit>> requestText({
    required String query,
    String? language,
  }) async {
    try {
      await _textRequests.create(query: query, language: language);
      return const Right(unit);
    } catch (e) {
      return Left(ExceptionMapper.map(e, context: 'requestText'));
    }
  }
}

/// A personal or imported collection as a card.
ChantBook chantBookFromPersonal(MyRecitationCollectionModel model) {
  return ChantBook(
    id: model.id,
    name: model.name,
    source: ChantBookSource.personal,
    imageUrl: model.imgUrl,
    chantCount: model.itemCount,
    audioItemCount: model.audioItemCount,
    subtitle: model.ownerName,
  );
}

/// Picks the collections out of the practices feed, in feed order, and
/// splits them by whether the user joined the space. A collection listed
/// twice (one space importing another's) is kept once, joined first.
/// [isPartial] marks a feed cut short by a failed page.
SpaceChantBooks splitSpaceChantBooks(
  List<GroupPractice> practices, {
  bool isPartial = false,
}) {
  final yours = <ChantBook>[];
  final others = <ChantBook>[];
  final seen = <String>{};
  final collections = practices.where(
    (p) => p.type == GroupPracticeType.collection && p.collection != null,
  );
  // Joined ones first, so a duplicate lands in "yours".
  final ordered = [
    ...collections.where((p) => p.isJoined),
    ...collections.where((p) => !p.isJoined),
  ];
  for (final practice in ordered) {
    final collection = practice.collection!;
    if (collection.id.isEmpty || !seen.add(collection.id)) continue;
    final book = ChantBook(
      id: collection.id,
      name: collection.name,
      source: ChantBookSource.space,
      imageUrl: collection.imageUrl,
      chantCount: collection.itemCount,
      audioItemCount: collection.audioItemCount,
      subtitle: _nonBlank(practice.groupName),
      groupId: _nonBlank(practice.groupId) ?? _nonBlank(collection.groupId),
      groupAvatarUrl: _nonBlank(practice.groupAvatarUrl),
      isJoinedSpace: practice.isJoined,
    );
    (practice.isJoined ? yours : others).add(book);
  }
  return SpaceChantBooks(yours: yours, others: others, isPartial: isPartial);
}

/// Flattens loaded book [details] (null where a book failed, same order as
/// [books]) into chant rows, in book order then the book's own order.
///
/// A text in more than one book is not listed twice. Each distinct
/// recording of it is kept (the same recording in two books once). A copy
/// without audio is listed only when no book has a recording of that text,
/// and then once. The first copy wins, so a joined space wins when [books]
/// lists those first.
SpaceChants splitSpaceChants(
  List<ChantBook> books,
  List<GroupRecitationCollection?> details,
) {
  final yoursAudio = <SpaceChant>[];
  final yoursText = <SpaceChant>[];
  final othersAudio = <SpaceChant>[];
  final othersText = <SpaceChant>[];
  final count = min(books.length, details.length);

  String? textKey(GroupRecitationCollectionItem item) =>
      _nonBlank(item.textId) ?? _nonBlank(item.id);

  // Texts with a recording in any book, so a text-only copy elsewhere
  // does not hide in "Text chants" what "Audio chants" already plays.
  final recordedTexts = <String>{};
  for (var i = 0; i < count; i++) {
    for (final item in details[i]?.items ?? const []) {
      final key = textKey(item);
      if (key != null && item.audio.isNotEmpty) recordedTexts.add(key);
    }
  }

  final seen = <String>{};
  for (var i = 0; i < count; i++) {
    final book = books[i];
    final detail = details[i];
    if (detail == null) continue;
    for (final item in detail.items) {
      final key = textKey(item);
      if (key == null) continue;
      if (item.audio.isEmpty) {
        if (recordedTexts.contains(key) || !seen.add(key)) continue;
      } else {
        final recordings = item.audio.map((a) => a.assetUrl).toList()..sort();
        if (!seen.add('$key\u0000${recordings.join('\u0000')}')) continue;
      }
      final chant = SpaceChant(
        item: item,
        collection: detail,
        spaceName: book.subtitle,
        groupAvatarUrl: book.groupAvatarUrl,
        isJoinedSpace: book.isJoinedSpace,
      );
      if (book.isJoinedSpace) {
        (chant.hasAudio ? yoursAudio : yoursText).add(chant);
      } else {
        (chant.hasAudio ? othersAudio : othersText).add(chant);
      }
    }
  }
  return SpaceChants(
    yoursAudio: yoursAudio,
    yoursText: yoursText,
    othersAudio: othersAudio,
    othersText: othersText,
    failedBookCount: details.take(count).where((d) => d == null).length,
  );
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
