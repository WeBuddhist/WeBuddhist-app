import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:fpdart/fpdart.dart';

/// Chant books for the Chants page. The screen reads only this, so when
/// the backend adds feed filters (Q5/Q6) only the implementation changes.
abstract class ChantsPageRepository {
  /// The user's own and imported chant books (needs a signed-in user).
  Future<Either<Failure, ChantBooksPage>> getMyChantBooks({
    int skip = 0,
    int limit = 20,
    String? search,
  });

  /// Chant books of public spaces, split by whether the user joined them.
  /// [language] renders space names.
  Future<Either<Failure, SpaceChantBooks>> getSpaceChantBooks({
    required String language,
  });

  /// The chants inside [books], read from each book's detail and split by
  /// joined space and by audio. Books that fail to load are left out; the
  /// call fails only when every book failed.
  Future<Either<Failure, SpaceChants>> getSpaceChants(SpaceChantBooks books);

  /// Asks the team for a text a search did not find ("Request text").
  /// Needs a signed-in user; a [RateLimitFailure] means the daily limit was
  /// reached.
  Future<Either<Failure, Unit>> requestText({
    required String query,
    String? language,
  });
}
