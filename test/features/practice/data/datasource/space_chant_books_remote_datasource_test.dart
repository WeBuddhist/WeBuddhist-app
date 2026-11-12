import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/practice/data/datasource/space_chant_books_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/repositories/chants_page_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// One collection card as `GET /author/groups/practices?types=collection`
/// served it on 2026-11-11 (signed URLs left out).
const _liveCard = {
  'type': 'collection',
  'practice_at': '2026-11-01T00:00:00+00:00',
  'is_joined': false,
  'group_id': '4cc9f2c0-da6c-41ab-85f3-4b569ff1a87d',
  'group_name': 'Compassionate Youth Association',
  'group_slug': null,
  'group_avatar_url': null,
  'series': null,
  'accumulator': null,
  'plan': null,
  'collection': {
    'id': '09d7f6d9-c7ca-4e9d-a13d-45f2274c4de0',
    'group_id': '4cc9f2c0-da6c-41ab-85f3-4b569ff1a87d',
    'name': 'TCV Morning Prayers',
    'img_url': null,
    'item_count': 3,
    'audio_item_count': 9,
    'created_at': '2026-10-20T00:00:00+00:00',
    'status': 'PRIVATE',
    'reference': null,
    'source_type': null,
    'owner': null,
    'already_imported': null,
  },
};

/// Answers every request with [body] and keeps the last request.
class _Recorder extends Interceptor {
  _Recorder(this.body);

  final Map<String, dynamic> body;
  RequestOptions? last;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    last = options;
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: body),
    );
  }
}

void main() {
  test('asks for chant books only, with membership and search', () async {
    final recorder = _Recorder({
      'practices': [_liveCard],
      'skip': 0,
      'limit': 100,
      'total': 1,
      'include_unfollowed': true,
    });
    final dio = Dio()..interceptors.add(recorder);
    final datasource = SpaceChantBooksRemoteDatasource(dio: dio);

    final page = await datasource.fetchChantBooks(
      membership: SpaceMembership.notJoined,
      language: 'bo',
      skip: 20,
      limit: 100,
      search: '  tara ',
    );

    expect(recorder.last!.path, '/author/groups/practices');
    expect(recorder.last!.queryParameters, {
      'types': 'collection',
      'membership': 'not_joined',
      'language': 'bo',
      'skip': 20,
      'limit': 100,
      'search': 'tara',
    });
    expect(page.practices, hasLength(1));
    expect(page.hasMore, isFalse);
  });

  test('leaves out a blank search', () async {
    final recorder = _Recorder({'practices': [], 'total': 0});
    final datasource = SpaceChantBooksRemoteDatasource(
      dio: Dio()..interceptors.add(recorder),
    );
    await datasource.fetchChantBooks(
      membership: SpaceMembership.all,
      language: 'en',
      skip: 0,
      limit: 100,
      search: '   ',
    );
    expect(recorder.last!.queryParameters.containsKey('search'), isFalse);
  });

  test('a live card shows its audio badge under other spaces', () async {
    final recorder = _Recorder({'practices': [_liveCard], 'total': 1});
    final datasource = SpaceChantBooksRemoteDatasource(
      dio: Dio()..interceptors.add(recorder),
    );
    final page = await datasource.fetchChantBooks(
      membership: SpaceMembership.all,
      language: 'en',
      skip: 0,
      limit: 100,
    );

    final books = splitSpaceChantBooks(page.practices);
    final book = books.others.single;
    expect(book.name, 'TCV Morning Prayers');
    expect(book.subtitle, 'Compassionate Youth Association');
    expect(book.chantCount, 3);
    expect(book.audioItemCount, 9);
    expect(book.hasAudio, isTrue);
    expect(books.hasYourSpaces, isFalse);
  });
}
