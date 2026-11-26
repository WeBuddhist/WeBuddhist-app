import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/config/api_config.dart';
import 'package:flutter_pecha/core/config/protected_routes.dart';
import 'package:flutter_pecha/features/home/data/datasource/home_feed_remote_datasource.dart';
import 'package:flutter_pecha/features/home/domain/entities/home_feed_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the request and answers with [body].
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);

  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

HomeFeedRemoteDatasource _datasource(_RecordingAdapter adapter) =>
    HomeFeedRemoteDatasource(
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
        ..httpClientAdapter = adapter,
    );

void main() {
  test('members read /api/v2/feed, with the cursor when paging', () async {
    final adapter = _RecordingAdapter({
      'items': <Object>[],
      'next_cursor': 'next',
    });
    final datasource = _datasource(adapter);

    final first = await datasource.fetchMemberFeed(language: 'bo');
    expect(adapter.last!.uri.path, '/api/v2/feed');
    expect(adapter.last!.uri.queryParameters, {'language': 'bo', 'limit': '20'});
    expect(adapter.last!.extra['no_cache'], isTrue);
    expect(first.next, const HomeFeedCursor('next'));

    await datasource.fetchMemberFeed(language: 'bo', cursor: 'next');
    expect(adapter.last!.uri.queryParameters, {
      'language': 'bo',
      'limit': '20',
      'cursor': 'next',
    });
  });

  test('guests read the public spaces feed by offset', () async {
    final adapter = _RecordingAdapter({
      'items': <Object>[],
      'skip': 40,
      'limit': 20,
      'total': 41,
      'include_unfollowed': true,
    });

    await _datasource(adapter).fetchPublicFeed(language: 'en', skip: 40);

    expect(adapter.last!.uri.path, '/api/v2/spaces/feed');
    expect(adapter.last!.uri.queryParameters, {
      'language': 'en',
      'include_unfollowed': 'true',
      'skip': '40',
      'limit': '20',
    });
  });

  test('a body that is not a page is an error', () async {
    final adapter = _RecordingAdapter(['not', 'a', 'page']);
    expect(
      _datasource(adapter).fetchMemberFeed(language: 'en'),
      throwsA(isA<Exception>()),
    );
  });

  test('/feed always sends the token; the spaces feed when it has one', () {
    expect(ProtectedRoutes.isProtected(ApiConfig.feedV2Path), isTrue);
    expect(ProtectedRoutes.isOptional(ApiConfig.spacesFeedV2Path), isTrue);
    expect(ProtectedRoutes.isProtected(ApiConfig.spacesFeedV2Path), isFalse);
    // The spaces list keeps its own rule.
    expect(ProtectedRoutes.isOptional(ApiConfig.spacesV2Path), isTrue);
  });
}
