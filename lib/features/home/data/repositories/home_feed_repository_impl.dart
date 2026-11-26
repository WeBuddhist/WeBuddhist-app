import 'package:flutter_pecha/core/error/exception_mapper.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/home/data/datasource/home_feed_remote_datasource.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';
import 'package:flutter_pecha/features/home/domain/repositories/home_feed_repository.dart';
import 'package:fpdart/fpdart.dart';

class HomeFeedRepositoryImpl implements HomeFeedRepository {
  HomeFeedRepositoryImpl({required this.remote});

  final HomeFeedRemoteDatasource remote;

  @override
  Future<Either<Failure, HomeFeedPage>> getFeed({
    required bool signedIn,
    required String language,
    HomeFeedPageToken? after,
  }) async {
    try {
      final page =
          signedIn
              ? await remote.fetchMemberFeed(
                language: language,
                cursor: after is HomeFeedCursor ? after.value : null,
              )
              : await remote.fetchPublicFeed(
                language: language,
                skip: after is HomeFeedOffset ? after.skip : 0,
              );
      return Right(page);
    } catch (e) {
      return Left(ExceptionMapper.map(e, context: 'getFeed'));
    }
  }
}
