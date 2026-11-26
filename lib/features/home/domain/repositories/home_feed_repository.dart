import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';
import 'package:fpdart/fpdart.dart';

abstract class HomeFeedRepository {
  /// A page of Home's feed: the member's `/feed` mix when [signedIn], else
  /// the public spaces feed.
  ///
  /// No [after] reads the first page (for members, a fresh mix). [after] is
  /// the previous page's `next`; one from the other audience is ignored and
  /// the first page is read.
  Future<Either<Failure, HomeFeedPage>> getFeed({
    required bool signedIn,
    required String language,
    HomeFeedPageToken? after,
  });
}
