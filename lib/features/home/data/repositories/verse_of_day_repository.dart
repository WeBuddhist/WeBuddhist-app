import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/home/data/datasource/home_local_datasource.dart';
import 'package:flutter_pecha/features/home/data/datasource/verse_of_day_remote_datasource.dart';
import 'package:flutter_pecha/features/home/data/models/verse_of_day_model.dart';
import 'package:flutter_pecha/features/home/domain/entities/verse_of_day.dart';
import 'package:flutter_pecha/features/home/domain/entities/verse_of_day_engagement.dart';
import 'package:flutter_pecha/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_pecha/features/home/domain/utils/verse_of_day_dates.dart';

class VerseOfDayRepository implements VerseOfDayRepositoryInterface {
  final VerseOfDayRemoteDatasource remote;
  final HomeLocalDatasource local;

  /// The device clock; tests pin it.
  final DateTime Function() _now;

  VerseOfDayRepository({
    required this.remote,
    required this.local,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<Either<Failure, VerseOfDay>> getVerseOfDay({
    required String language,
    String? tradition,
  }) async {
    final cached = local.readVerseOfDay(language, tradition: tradition);
    if (cached != null) {
      unawaited(_refresh(language, tradition).catchError((_) {}));
      return Right(cached.toEntity());
    }

    try {
      final model = await remote.fetchVerseOfDay(
        language: language,
        tradition: tradition,
      );
      if (model == null) {
        return const Left(NotFoundFailure('No verse of day today'));
      }
      await local.saveVerseOfDay(language, model, tradition: tradition);
      return Right(model.toEntity());
    } catch (e) {
      return Left(_toFailure(e, 'Failed to get verse of day'));
    }
  }

  @override
  Stream<Either<Failure, List<VerseOfDay>>> watchRecentVerses({
    required String language,
    String? tradition,
  }) async* {
    // Listens before the first refresh, so a store write that lands while it
    // runs (a pull-to-refresh) is not missed. Writes made by that refresh
    // re-emit the same week, which is harmless.
    final changes = StreamController<void>();
    final subscription = local
        .watchKey(local.recentVerseDatesKey(language, tradition: tradition))
        .listen(changes.add);

    try {
      final cached = local.readRecentVerses(language, tradition: tradition);
      if (cached != null) yield Right(_toEntities(cached));

      try {
        await _refreshRecent(language, tradition);
        final refreshed = local.readRecentVerses(
          language,
          tradition: tradition,
        );
        if (refreshed != null) yield Right(_toEntities(refreshed));
      } catch (e) {
        if (cached == null) {
          yield Left(_toFailure(e, 'Failed to get recent verses of day'));
        }
      }

      await for (final _ in changes.stream) {
        final latest = local.readRecentVerses(language, tradition: tradition);
        if (latest != null) yield Right(_toEntities(latest));
      }
    } finally {
      await subscription.cancel();
      // Not awaited: close() only completes once a listener sees "done",
      // and a watcher can cancel before the buffer is ever listened to.
      unawaited(changes.close());
    }
  }

  @override
  Future<Either<Failure, Unit>> refreshRecentVerses({
    required String language,
    String? tradition,
  }) async {
    try {
      await _refreshRecent(language, tradition);
      return const Right(unit);
    } catch (e) {
      return Left(_toFailure(e, 'Failed to refresh recent verses of day'));
    }
  }

  List<VerseOfDay> _toEntities(List<VerseOfDayModel> models) => [
    for (final model in models) model.toEntity(),
  ];

  /// Today from `/today` (it decides which day "today" is), then the six days
  /// before it from `?date=`, in parallel. A past day already fetched within
  /// [VerseOfDayCacheEntry.maxAge] is not asked for again; one that fails
  /// keeps its old entry. Throws only when today's call fails.
  Future<void> _refreshRecent(String language, String? tradition) async {
    final today = await remote.fetchVerseOfDay(
      language: language,
      tradition: tradition,
    );
    final now = _now();
    final anchor =
        (today == null ? null : parseVerseOfDayDate(today.date)) ?? now;
    final dates = daysEndingOn(anchor, verseOfDayWeekLength);

    await local.saveVerseOfDayEntry(
      language,
      dates.first,
      VerseOfDayCacheEntry(fetchedAt: now, verse: today),
      tradition: tradition,
    );
    if (today != null) {
      await local.saveVerseOfDay(language, today, tradition: tradition);
    }

    await Future.wait([
      for (final date in dates.skip(1))
        if (!(local
                .readVerseOfDayEntry(language, date, tradition: tradition)
                ?.isFreshAt(now) ??
            false))
          _refreshDay(language, tradition, date, now),
    ]);

    await local.saveRecentVerseDates(language, dates, tradition: tradition);
  }

  Future<void> _refreshDay(
    String language,
    String? tradition,
    String date,
    DateTime now,
  ) async {
    try {
      final verse = await remote.fetchVerseOfDayByDate(
        language: language,
        date: date,
        tradition: tradition,
      );
      await local.saveVerseOfDayEntry(
        language,
        date,
        VerseOfDayCacheEntry(fetchedAt: now, verse: verse),
        tradition: tradition,
      );
    } catch (_) {
      // The old entry, if any, stays; the next refresh asks again.
    }
  }

  @override
  Future<Either<Failure, VerseOfDayLikes>> getLikes(String verseId) async {
    try {
      final model = await remote.fetchLikes(verseId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(_toFailure(e, 'Failed to load likes'));
    }
  }

  @override
  Future<Either<Failure, Unit>> likeVerse(String verseId) async {
    try {
      await remote.likeVerse(verseId);
      return const Right(unit);
    } catch (e) {
      return Left(_toFailure(e, 'Failed to like verse'));
    }
  }

  @override
  Future<Either<Failure, Unit>> unlikeVerse(String verseId) async {
    try {
      await remote.unlikeVerse(verseId);
      return const Right(unit);
    } catch (e) {
      return Left(_toFailure(e, 'Failed to unlike verse'));
    }
  }

  @override
  Future<Either<Failure, VerseOfDayLikersPage>> getLikers({
    required String verseId,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final model = await remote.fetchLikers(
        verseId: verseId,
        skip: skip,
        limit: limit,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(_toFailure(e, 'Failed to load likers'));
    }
  }

  @override
  Future<Either<Failure, VerseOfDayCommentsPage>> getComments({
    required String verseId,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final model = await remote.fetchComments(
        verseId: verseId,
        skip: skip,
        limit: limit,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(_toFailure(e, 'Failed to load comments'));
    }
  }

  @override
  Future<Either<Failure, VerseOfDayComment>> getComment({
    required String verseId,
    required String commentId,
  }) async {
    try {
      final model = await remote.fetchComment(
        verseId: verseId,
        commentId: commentId,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(_toFailure(e, 'Failed to load comment'));
    }
  }

  @override
  Future<Either<Failure, VerseOfDayComment>> createComment({
    required String verseId,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      final model = await remote.createComment(
        verseId: verseId,
        text: text,
        parentCommentId: parentCommentId,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(_toFailure(e, 'Failed to post comment'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) async {
    try {
      await remote.deleteComment(commentId);
      return const Right(unit);
    } catch (e) {
      return Left(_toFailure(e, 'Failed to delete comment'));
    }
  }

  @override
  Future<Either<Failure, Unit>> likeComment(String commentId) async {
    try {
      await remote.likeComment(commentId);
      return const Right(unit);
    } catch (e) {
      return Left(_toFailure(e, 'Failed to like comment'));
    }
  }

  @override
  Future<Either<Failure, Unit>> unlikeComment(String commentId) async {
    try {
      await remote.unlikeComment(commentId);
      return const Right(unit);
    } catch (e) {
      return Left(_toFailure(e, 'Failed to unlike comment'));
    }
  }

  Future<void> _refresh(String language, String? tradition) async {
    final model = await remote.fetchVerseOfDay(
      language: language,
      tradition: tradition,
    );
    if (model != null) {
      await local.saveVerseOfDay(language, model, tradition: tradition);
    }
  }

  Failure _toFailure(Object error, String fallback) {
    if (error is ServerException) return ServerFailure(error.message);
    if (error is NetworkException) return NetworkFailure(error.message);
    if (error is NotFoundException) return NotFoundFailure(error.message);
    if (error is AuthenticationException) {
      return AuthenticationFailure(error.message);
    }
    if (error is RateLimitException) return RateLimitFailure(error.message);
    return UnknownFailure('$fallback: $error');
  }
}
