import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/mala/data/datasources/mala_appearance_remote_datasource.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [body] and records what was sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  final Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

MalaAppearanceRemoteDataSource _source(_Adapter adapter) =>
    MalaAppearanceRemoteDataSource(
      dio: Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
        ..httpClientAdapter = adapter,
    );

void main() {
  test('skins parses GET /mala-skins on v2', () async {
    final adapter = _Adapter({
      'mala_skins': [
        {
          'id': 'a',
          'name': 'ellipse',
          'url': 'https://s3/a.webp',
          'default': true,
          'owner_space_id': null,
        },
        {'id': 'b', 'name': 'Dark Blue', 'url': 'https://s3/b.webp'},
        // No url: left out.
        {'id': 'c', 'name': 'broken', 'url': ''},
      ],
    });

    final skins = await _source(adapter).skins();

    expect(adapter.requests.single.uri.path, '/api/v2/mala-skins');
    expect(skins, const [
      MalaSkin(
        id: 'a',
        name: 'ellipse',
        url: 'https://s3/a.webp',
        isDefault: true,
      ),
      MalaSkin(id: 'b', name: 'Dark Blue', url: 'https://s3/b.webp'),
    ]);
  });

  test('deityImages sorts by display_order and keeps the default', () async {
    final adapter = _Adapter({
      'mantra_id': 'm1',
      'deity_images': [
        {
          'id': 'second',
          'image': {'thumbnail': 'https://s3/2.jpg'},
          'is_default': false,
          'display_order': 1,
        },
        {
          'id': 'first',
          'image': {'thumbnail': 'https://s3/1.jpg'},
          'is_default': true,
          'display_order': 0,
        },
      ],
    });

    final images = await _source(adapter).deityImages('m1');

    expect(adapter.requests.single.uri.path, '/api/v2/mantras/m1/images');
    expect(images.map((i) => i.id), ['first', 'second']);
    expect(images.first.isDefault, isTrue);
  });

  test(
    'updateAppearance sends only the changed field, null included',
    () async {
      final adapter = _Adapter({
        'mantra_id': 'm1',
        'deity_image_id': null,
        'mala_skin_id': 'b',
        'deity_image': {'thumbnail': 'https://s3/1.jpg'},
        'mala_skin_url': 'https://s3/b.webp',
      });

      final result = await _source(
        adapter,
      ).updateAppearance('m1', deityImage: (id: null));

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.uri.path, '/api/v2/users/me/mantras/m1/appearance');
      expect(request.data, {'deity_image_id': null});
      expect(result.deityImageId, isNull);
      expect(result.malaSkinId, 'b');
      expect(result.malaSkinUrl, 'https://s3/b.webp');
      expect(result.deityImage?.thumbnail, 'https://s3/1.jpg');
    },
  );

  test('skin names are tidied for display', () {
    expect(
      const MalaSkin(id: 'x', name: 'bodhi_seed', url: 'u').displayName,
      'Bodhi seed',
    );
    expect(
      const MalaSkin(id: 'x', name: 'Dark Blue', url: 'u').displayName,
      'Dark Blue',
    );
  });
}
