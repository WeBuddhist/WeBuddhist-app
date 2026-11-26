import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/error/exception_mapper.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/practice/data/datasource/space_chant_books_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

/// Which space practices a Practice tab row shows: plans, or accumulations,
/// from the spaces the user joined or from the ones they have not.
///
/// Chant books come from [spaceChantBooksProvider], which the Chants page
/// already reads and splits by membership.
enum PracticeSpaceRow {
  plans([GroupPracticeType.series, GroupPracticeType.plan]),
  accumulations([GroupPracticeType.accumulator]);

  const PracticeSpaceRow(this.types);

  /// Feed types read for this row, one request each.
  final List<GroupPracticeType> types;
}

/// Key of [practiceSpacePracticesProvider].
typedef PracticeSpaceQuery = ({PracticeSpaceRow row, bool joined});

/// Cards a Practice tab rail shows; See all leads to fuller lists.
const int practiceSpacePreviewLimit = 10;

/// One row of space practices for the Practice tab. "From your spaces"
/// reads the joined spaces and "Discover more" the rest. Empty for a guest
/// asking for joined spaces. Re-read when sign-in, the content language,
/// or the user's space memberships change.
final practiceSpacePracticesProvider = FutureProvider.autoDispose
    .family<Either<Failure, List<GroupPractice>>, PracticeSpaceQuery>((
      ref,
      query,
    ) {
      final signedIn = ref.watch(
        authProvider.select((auth) => auth.isLoggedIn && !auth.isGuest),
      );
      ref.watch(mySpaceMembershipEpochProvider);
      final language = ref.watch(contentLanguageProvider);
      if (query.joined && !signedIn) {
        return Future.value(const Right(<GroupPractice>[]));
      }
      final datasource = SpaceChantBooksRemoteDatasource(
        dio: ref.watch(dioProvider),
      );
      return ref.cacheSuccessFor(
        _loadRow(datasource, query, language),
        spaceChantsCacheTime,
      );
    });

Future<Either<Failure, List<GroupPractice>>> _loadRow(
  SpaceChantBooksRemoteDatasource datasource,
  PracticeSpaceQuery query,
  String language,
) async {
  try {
    final pages = await Future.wait([
      for (final type in query.row.types)
        datasource.fetchPractices(
          type: type,
          membership:
              query.joined ? SpaceMembership.joined : SpaceMembership.notJoined,
          language: language,
          skip: 0,
          limit: practiceSpacePreviewLimit,
        ),
    ]);
    final practices = [
      for (final page in pages) ...page.practices.where(_hasPayload),
    ];
    _sortNewestFirst(practices);
    return Right(practices.take(practiceSpacePreviewLimit).toList());
  } catch (e) {
    return Left(ExceptionMapper.map(e, context: 'practiceSpacePractices'));
  }
}

/// Feed page size, and the most pages read per type, for full lists.
const int _allPlansPageSize = 50;
const int _allPlansMaxPages = 10;

/// Every practice of one row (plans and series, or accumulations) from the
/// spaces the user joined (`joined` true) or has not. The Plans screen's
/// space pills and Practice search read it. Empty for a guest asking for
/// joined spaces. Re-read on the same changes as the rails.
final practiceSpaceFeedProvider = FutureProvider.autoDispose
    .family<Either<Failure, List<GroupPractice>>, PracticeSpaceQuery>((
      ref,
      query,
    ) {
      final signedIn = ref.watch(
        authProvider.select((auth) => auth.isLoggedIn && !auth.isGuest),
      );
      ref.watch(mySpaceMembershipEpochProvider);
      final language = ref.watch(contentLanguageProvider);
      if (query.joined && !signedIn) {
        return Future.value(const Right(<GroupPractice>[]));
      }
      final datasource = SpaceChantBooksRemoteDatasource(
        dio: ref.watch(dioProvider),
      );
      return ref.cacheSuccessFor(
        _loadFeed(datasource, query, language),
        spaceChantsCacheTime,
      );
    });

Future<Either<Failure, List<GroupPractice>>> _loadFeed(
  SpaceChantBooksRemoteDatasource datasource,
  PracticeSpaceQuery query,
  String language,
) async {
  try {
    final membership =
        query.joined ? SpaceMembership.joined : SpaceMembership.notJoined;
    final lists = await Future.wait([
      for (final type in query.row.types)
        _fetchEveryPage(datasource, type, membership, language),
    ]);
    final practices = [for (final list in lists) ...list.where(_hasPayload)];
    _sortNewestFirst(practices);
    return Right(practices);
  } catch (e) {
    return Left(ExceptionMapper.map(e, context: 'practiceSpaceFeed'));
  }
}

/// Key of [practiceSpaceSearchProvider].
typedef PracticeSpaceSearchQuery = ({PracticeSpaceRow row, String query});

/// Space practices of one row whose title holds the query, from the
/// joined spaces and then the rest. The feed's `search` matches only chant
/// book names, so the full feed is matched here, as space chants are.
final practiceSpaceSearchProvider = FutureProvider.autoDispose.family<
  Either<Failure, List<GroupPractice>>,
  PracticeSpaceSearchQuery
>((ref, search) async {
  final needle = search.query.trim().toLowerCase();
  if (needle.isEmpty) return const Right(<GroupPractice>[]);
  final results = await Future.wait([
    ref.watch(
      practiceSpaceFeedProvider((row: search.row, joined: true)).future,
    ),
    ref.watch(
      practiceSpaceFeedProvider((row: search.row, joined: false)).future,
    ),
  ]);
  final matches = <GroupPractice>[];
  for (final result in results) {
    final failure = result.getLeft().toNullable();
    if (failure != null) return Left(failure);
    matches.addAll(
      result
          .getOrElse((_) => const [])
          .where((p) => spacePracticeTitle(p).toLowerCase().contains(needle)),
    );
  }
  return Right(matches);
});

/// The title a space practice card shows.
String spacePracticeTitle(GroupPractice practice) =>
    practice.series?.title ??
    practice.plan?.title ??
    practice.accumulator?.title ??
    practice.collection?.name ??
    '';

/// Reads one type's feed page by page, up to [_allPlansMaxPages] pages.
Future<List<GroupPractice>> _fetchEveryPage(
  SpaceChantBooksRemoteDatasource datasource,
  GroupPracticeType type,
  SpaceMembership membership,
  String language,
) async {
  final practices = <GroupPractice>[];
  for (var i = 0; i < _allPlansMaxPages; i++) {
    final page = await datasource.fetchPractices(
      type: type,
      membership: membership,
      language: language,
      skip: practices.length,
      limit: _allPlansPageSize,
    );
    practices.addAll(page.practices);
    if (!page.hasMore || page.practices.isEmpty) break;
  }
  return practices;
}

/// Newest first across merged types, as the feed orders one type.
void _sortNewestFirst(List<GroupPractice> practices) {
  practices.sort((a, b) {
    final aAt = a.practiceAt, bAt = b.practiceAt;
    if (aAt == null && bAt == null) return 0;
    if (aAt == null || bAt == null) return aAt == null ? 1 : -1;
    return bAt.compareTo(aAt);
  });
}

/// Drops cards the feed sent without their body, which no card can draw.
bool _hasPayload(GroupPractice practice) {
  return switch (practice.type) {
    GroupPracticeType.series => practice.series != null,
    GroupPracticeType.plan => practice.plan != null,
    GroupPracticeType.accumulator => practice.accumulator != null,
    GroupPracticeType.collection => false,
  };
}
