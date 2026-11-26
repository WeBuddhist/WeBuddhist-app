import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/config/api_config.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/features/home/data/models/home_feed_model.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';

/// Home's feed: `/feed` for members, the public spaces feed for guests
/// (`/feed` answers 403 without a token).
///
/// HTTP failures surface as the [DioException] the error interceptor wraps
/// its typed exception in; the repository maps it.
class HomeFeedRemoteDatasource {
  HomeFeedRemoteDatasource({required this.dio});

  final Dio dio;

  static const int pageSize = 20;

  Future<HomeFeedPage> fetchMemberFeed({
    required String language,
    String? cursor,
    int limit = pageSize,
  }) async {
    final json = await fetchMemberFeedJson(
      language: language,
      cursor: cursor,
      limit: limit,
    );
    return HomeFeedModel.parseMemberPage(json, language: language);
  }

  /// Raw `GET /api/v2/feed` page as served, so a cache can store it as is.
  /// No [cursor] asks the server for a fresh mix.
  Future<Map<String, dynamic>> fetchMemberFeedJson({
    required String language,
    String? cursor,
    int limit = pageSize,
  }) async {
    final response = await dio.get<Object?>(
      ApiConfig.feedV2Path,
      queryParameters: {
        'language': language,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
      options: Options(extra: {'no_cache': true}),
    );
    return _page(response.data);
  }

  Future<HomeFeedPage> fetchPublicFeed({
    required String language,
    int skip = 0,
    int limit = pageSize,
  }) async {
    final json = await fetchPublicFeedJson(
      language: language,
      skip: skip,
      limit: limit,
    );
    return HomeFeedModel.parsePublicPage(json, language: language);
  }

  /// Raw `GET /api/v2/spaces/feed?include_unfollowed=true` page as served.
  Future<Map<String, dynamic>> fetchPublicFeedJson({
    required String language,
    int skip = 0,
    int limit = pageSize,
  }) async {
    final response = await dio.get<Object?>(
      ApiConfig.spacesFeedV2Path,
      queryParameters: {
        'language': language,
        'include_unfollowed': true,
        'skip': skip,
        'limit': limit,
      },
      options: Options(extra: {'no_cache': true}),
    );
    return _page(response.data);
  }

  static Map<String, dynamic> _page(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const ServerException('Unexpected feed response');
  }
}
