import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_key.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_source.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_store.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_local_datasource.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_remote_datasource.dart';
import 'package:flutter_pecha/features/mala/data/models/accumulator_group_model.dart';
import 'package:flutter_pecha/features/mala/data/models/accumulator_model.dart';
import 'package:flutter_pecha/features/mala/domain/entities/accumulator_group.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_count.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/domain/repositories/mala_repository.dart';

class MalaRepositoryImpl implements MalaRepository {
  MalaRepositoryImpl({required this.remote, this.local, ScreenCacheStore? store})
    : store = store ?? ScreenCacheStore();

  final MalaRemoteDataSource remote;
  final MalaLocalDataSource? local;
  final ScreenCacheStore store;

  @override
  Stream<Either<Failure, List<AccumulatorGroup>>> watchJoinedAccumulatorGroups(
    String accumulatorId, {
    String? language,
  }) {
    return joinedAccumulatorGroupsSource(
      accumulatorId,
      language: language,
    ).watch();
  }

  @override
  Future<Either<Failure, List<AccumulatorGroup>>> refreshJoinedAccumulatorGroups(
    String accumulatorId, {
    String? language,
  }) {
    return joinedAccumulatorGroupsSource(
      accumulatorId,
      language: language,
    ).refresh();
  }

  @override
  ScreenCacheSource<List<AccumulatorGroup>> joinedAccumulatorGroupsSource(
    String accumulatorId, {
    String? language,
  }) {
    final userId = store.currentUserIdSync;
    return ScreenCacheSource(
      store: store,
      key: ScreenCacheKey.user(
        'joined_accumulator_groups',
        userId: userId,
        language: language ?? 'all',
        params: [accumulatorId],
      ),
      fetchJson:
          () => remote.fetchAccumulatorGroupsJson(
            accumulatorId,
            joinedOnly: true,
            language: language,
          ),
      fromJson:
          (json) =>
              AccumulatorGroupsResponseModel.fromJson(
                json as Map<String, dynamic>,
              ).groups.map((group) => group.toEntity()).toList(),
      failureMessage: 'Failed to load accumulator groups',
    );
  }

  @override
  Future<Either<Failure, List<Mantra>>> getCatalogue({
    String? language,
    String? search,
    String? userId,
  }) async {
    final cacheLanguage = language ?? 'en';
    final cacheUser =
        (search == null || search.trim().isEmpty) &&
                userId != null &&
                userId.isNotEmpty
            ? userId
            : null;
    final cached =
        cacheUser == null
            ? null
            : local?.readCatalogue(cacheUser, cacheLanguage);
    if (cached != null) {
      unawaited(refreshCatalogue(userId: cacheUser!, language: cacheLanguage));
      return Right(cached.map((preset) => preset.toEntity()).toList());
    }

    try {
      final presets =
          cacheUser == null
              ? await remote.fetchPresets(language: language, search: search)
              : await _fetchAndStore(cacheUser, cacheLanguage);
      return Right(presets.map((p) => p.toEntity()).toList());
    } on AppException catch (e) {
      return _legacyCatalogueOr(cacheUser, cacheLanguage, _toFailure(e));
    } catch (e) {
      return _legacyCatalogueOr(
        cacheUser,
        cacheLanguage,
        UnknownFailure('Failed to load catalogue: $e'),
      );
    }
  }

  /// Offline right after the cache-key bump: serve a pre-v3 cache (no usage
  /// times) rather than an error. The next online load replaces it.
  Either<Failure, List<Mantra>> _legacyCatalogueOr(
    String? userId,
    String language,
    Failure failure,
  ) {
    final legacy =
        userId == null
            ? null
            : local?.readCatalogue(userId, language, allowLegacy: true);
    if (legacy == null) return Left(failure);
    return Right(legacy.map((preset) => preset.toEntity()).toList());
  }

  /// In-flight catalogue fetches by account and language. The first load
  /// and the mala screen's refresh on entry often start together; they
  /// share one download of every page instead of making two.
  final _catalogueFetches = <String, Future<List<PresetAccumulatorModel>>>{};

  Future<List<PresetAccumulatorModel>> _fetchAndStore(
    String userId,
    String language,
  ) {
    final key = '$userId:$language';
    return _catalogueFetches[key] ??= () async {
      try {
        final presets = await remote.fetchPresets(language: language);
        await local?.writeCatalogue(userId, language, presets);
        return presets;
      } finally {
        _catalogueFetches.remove(key);
      }
    }();
  }

  @override
  Future<void> refreshCatalogue({
    required String userId,
    String? language,
  }) async {
    try {
      await _fetchAndStore(userId, language ?? 'en');
    } catch (_) {
      // Offline or failed: the cached catalogue stays until the next one.
    }
  }

  @override
  Future<Either<Failure, MalaCount>> getAccumulatorDetail(
    String parentId,
  ) async {
    try {
      final detail = await remote.fetchAccumulatorDetail(parentId);
      // No accumulator yet for this preset — seed at 0, lazily create later.
      return Right(detail?.toMalaCount() ?? const MalaCount(total: 0));
    } on AppException catch (e) {
      return Left(_toFailure(e));
    } catch (e) {
      return Left(UnknownFailure('Failed to load accumulator detail: $e'));
    }
  }

  @override
  Future<Either<Failure, MalaCount>> createUserAccumulator(
    String parentId,
  ) async {
    try {
      final created = await remote.createUserAccumulator(parentId);
      return Right(created.toMalaCount());
    } on AppException catch (e) {
      return Left(_toFailure(e));
    } catch (e) {
      return Left(UnknownFailure('Failed to create accumulator: $e'));
    }
  }

  @override
  Future<Either<Failure, MalaCount>> updateUserAccumulator({
    required String accumulatorId,
    required int currentCount,
  }) async {
    try {
      final updated = await remote.updateUserAccumulator(
        accumulatorId: accumulatorId,
        currentCount: currentCount,
      );
      return Right(updated.toMalaCount());
    } on AppException catch (e) {
      return Left(_toFailure(e));
    } catch (e) {
      return Left(UnknownFailure('Failed to update accumulator: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteUserAccumulator(
    String accumulatorId,
  ) async {
    try {
      await remote.deleteUserAccumulator(accumulatorId);
      return const Right(unit);
    } on AppException catch (e) {
      return Left(_toFailure(e));
    } catch (e) {
      return Left(UnknownFailure('Failed to delete accumulator: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AccumulatorGroup>>> getJoinedAccumulatorGroups(
    String accumulatorId, {
    String? language,
  }) async {
    try {
      final groups = await remote.fetchAccumulatorGroups(
        accumulatorId,
        joinedOnly: true,
        language: language,
      );
      return Right(groups.map((group) => group.toEntity()).toList());
    } on AppException catch (e) {
      return Left(_toFailure(e));
    } catch (e) {
      return Left(UnknownFailure('Failed to load accumulator groups: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> submitGroupAccumulatorCount({
    required String groupAccumulatorId,
    required int currentCount,
  }) async {
    try {
      await remote.submitGroupCount(groupAccumulatorId, currentCount);
      return const Right(unit);
    } on AppException catch (e) {
      return Left(_toFailure(e));
    } catch (e) {
      return Left(UnknownFailure('Failed to submit group count: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteGroupAccumulator(
    String groupAccumulatorId,
  ) async {
    try {
      await remote.deleteGroupAccumulator(groupAccumulatorId);
      return const Right(unit);
    } on AppException catch (e) {
      return Left(_toFailure(e));
    } catch (e) {
      return Left(UnknownFailure('Failed to delete group accumulator: $e'));
    }
  }

  Failure _toFailure(AppException e) {
    if (e is AuthenticationException) return AuthenticationFailure(e.message);
    if (e is NotFoundException) return NotFoundFailure(e.message);
    if (e is RateLimitException) return RateLimitFailure(e.message);
    if (e is NetworkException) return NetworkFailure(e.message);
    if (e is ServerException) return ServerFailure(e.message);
    return UnknownFailure(e.message);
  }
}
