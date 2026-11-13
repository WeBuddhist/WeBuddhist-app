import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/config/api_config.dart';
import 'package:flutter_pecha/core/config/protected_routes.dart';
import 'package:flutter_pecha/features/connect/data/datasource/connect_remote_datasource.dart';
import 'package:flutter_pecha/features/connect/domain/entities/space_sort.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the request and answers with [body].
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);

  final Map<String, dynamic> body;
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

void main() {
  late _RecordingAdapter adapter;
  late ConnectRemoteDatasource datasource;

  setUp(() {
    adapter = _RecordingAdapter({
      'spaces': [
        {
          'id': 's1',
          'slug': 's1',
          'space_type': 'PAGE',
          'member_count': 1200,
          'metadata': {'title': 'WeBuddhist'},
        },
      ],
      'skip': 0,
      'limit': 20,
      'total': 1,
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
      ..httpClientAdapter = adapter;
    datasource = ConnectRemoteDatasource(dio: dio);
  });

  test('lists communities from /api/v2/spaces with the sort', () async {
    final page = await datasource.fetchDiscoverGroups(
      language: 'en',
      skip: 20,
      sort: SpaceSort.newlyAdded,
    );

    final request = adapter.last!;
    expect(request.uri.path, '/api/v2/spaces');
    expect(request.uri.queryParameters, {
      'language': 'en',
      'space_type': 'COMMUNITY',
      'skip': '20',
      'limit': '20',
      'sort_by': 'created_at',
      'sort_order': 'desc',
    });

    expect(page.groups.single.title, 'WeBuddhist');
    expect(page.groups.single.groupType, GroupType.page);
    expect(page.groups.single.memberCount, 1200);
  });

  test('search can include joined spaces; no sort sends none', () async {
    await datasource.fetchDiscoverGroups(
      language: 'en',
      search: '  Buddha ',
      includeJoined: true,
    );

    final query = adapter.last!.uri.queryParameters;
    expect(query['search'], 'Buddha');
    expect(query['include_joined'], 'true');
    expect(query.containsKey('sort_by'), isFalse);
  });

  test('sorts map to the API values', () {
    expect(SpaceSort.popular.apiValue, 'member_count');
    expect(SpaceSort.newlyAdded.apiValue, 'created_at');
    expect(SpaceSort.mostActive.apiValue, 'updated_at');
  });

  test('the v2 spaces path sends the token when signed in', () {
    expect(ProtectedRoutes.isOptional(ApiConfig.spacesV2Path), isTrue);
    expect(ProtectedRoutes.isProtected(ApiConfig.spacesV2Path), isFalse);
  });
}
