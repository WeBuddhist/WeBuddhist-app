import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers each request with the next page and records what was sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.pages);

  final List<Object> pages;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = pages[requests.length];
    requests.add(options);
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

Map<String, dynamic> _row(String id, {String? lastUsedAt}) => {
  'id': id,
  'mantra': {'id': 'm-$id', 'mantra': 'om'},
  'space_id': null,
  'last_used_at': lastUsedAt,
};

void main() {
  test('the catalogue comes from v2 accumulations, platform owned', () async {
    final adapter = _Adapter([
      {
        'accumulators': [
          _row('a'),
          _row('b', lastUsedAt: '2026-11-18T07:42:10+00:00'),
        ],
        'total': 2,
        'skip': 0,
        'limit': 100,
        'last_used_id': 'b',
      },
    ]);
    final source = MalaRemoteDataSource(
      dio: Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
        ..httpClientAdapter = adapter,
    );

    final presets = await source.fetchPresets(language: 'bo', search: ' tara ');

    final request = adapter.requests.single;
    expect(request.uri.path, '/api/v2/accumulations');
    expect(request.uri.queryParameters, {
      'owner_type': 'platform',
      'skip': '0',
      'limit': '100',
      'language': 'bo',
      'search': 'tara',
    });
    expect(request.extra['no_cache'], isTrue);
    expect(presets.map((p) => p.id), ['a', 'b']);
    expect(presets.first.lastUsedAt, isNull);
    expect(presets.last.lastUsedAt, DateTime.utc(2026, 11, 18, 7, 42, 10));
  });
}
