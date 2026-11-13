import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/group_profile/data/models/group_practice_model.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';

/// `membership` of `GET /author/groups/practices`.
enum SpaceMembership {
  /// Spaces the user joined.
  joined('joined'),

  /// Published public spaces the user has not joined.
  notJoined('not_joined'),

  /// Both.
  all('all');

  const SpaceMembership(this.apiValue);
  final String apiValue;
}

/// Space chant books from the practices feed, asked for with
/// `types=collection` so only chant books come back and count toward
/// `total`. Kept apart from the group profile datasource, whose feed
/// method serves every practice type.
///
/// Both reads skip the HTTP cache, as the group profile datasource does
/// for these paths: the feed carries the caller's `is_joined`, and a
/// pull-to-refresh must see a chant added to a book since the last read.
/// The Chants page keeps loaded results itself (`cacheSuccessFor`).
class SpaceChantBooksRemoteDatasource {
  SpaceChantBooksRemoteDatasource({required this.dio});

  final Dio dio;

  static final Options _noCache = Options(extra: {'no_cache': true});

  /// GET /author/groups/practices?types=collection
  ///
  /// [search] matches chant-book names; errors propagate for the
  /// repository to map.
  Future<GroupPracticesPage> fetchChantBooks({
    required SpaceMembership membership,
    required String language,
    required int skip,
    required int limit,
    String? search,
  }) async {
    final query = search?.trim() ?? '';
    final response = await dio.get(
      '/author/groups/practices',
      queryParameters: {
        'types': 'collection',
        'membership': membership.apiValue,
        'language': language,
        'skip': skip,
        'limit': limit,
        if (query.isNotEmpty) 'search': query,
      },
      options: _noCache,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Unexpected /author/groups/practices payload type',
      );
    }
    return GroupPracticesPageModel.fromJson(data).toEntity();
  }

  /// GET /author/groups/recitation-collections/{collectionId}
  ///
  /// The feed sends no items, so each book's chants come from its detail.
  Future<GroupRecitationCollection> fetchChantBookDetail(
    String collectionId,
  ) async {
    final response = await dio.get(
      '/author/groups/recitation-collections/$collectionId',
      options: _noCache,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Unexpected /author/groups/recitation-collections payload type',
      );
    }
    return GroupRecitationCollectionModel.fromJson(data).toEntity();
  }
}
