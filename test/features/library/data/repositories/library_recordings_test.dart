import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/library/data/datasource/library_remote_datasource.dart';
import 'package:flutter_pecha/features/library/data/models/library_json.dart';
import 'package:flutter_pecha/features/library/data/models/library_recording.dart';
import 'package:flutter_pecha/features/library/data/models/library_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../library_test_server.dart';

Map<String, dynamic> _recording(
  String id, {
  String audioId = 'aud-1',
  String? editionId = 'ed-1',
  Map<String, String> title = const {'en': 'Voice only'},
}) => {
  'id': id,
  'title': title,
  'duration_ms': 218636,
  'audio_id': audioId,
  'text_id': 'text-1',
  'edition_id': editionId,
  'format': 'm4a',
  'size_bytes': 3536961,
};

void main() {
  group('models', () {
    test('parse a recording, a performance and an audio url', () {
      final recording = LibraryRecording.fromJson(_recording('rec-1'));
      expect(recording.id, 'rec-1');
      expect(recording.durationMs, 218636);
      expect(recording.editionId, 'ed-1');
      expect(recording.titleIn('bo'), 'Voice only');

      final audio = LibraryAudio.fromJson({
        'id': 'aud-1',
        'title': {'en': 'Praise — with music', 'bo': 'བསྟོད་པ།'},
        'language': 'bo',
        'text_id': 'text-1',
        'contributions': [
          {
            'type': 'person',
            'role': 'narrator',
            'name': {'en': 'Dechen Wangmo'},
          },
        ],
        'recordings': ['rec-1'],
      });
      expect(audio.titleIn('bo'), 'བསྟོད་པ།');
      expect(audio.performerNames, ['Dechen Wangmo']);
      expect(audio.recordingIds, ['rec-1']);

      final url = LibraryAudioUrl.fromJson({
        'url': ' https://s3/objects/rec-1?sig ',
        'expires_in': 3600,
      });
      expect(url.url, 'https://s3/objects/rec-1?sig');
      expect(url.expiresIn, 3600);
    });

    test('pickLocalized prefers the language, then English, then any', () {
      const values = {'zh-Hant': '藏', 'en': 'Tibetan', 'bo': ''};
      expect(pickLocalized(values, 'zh'), '藏');
      expect(pickLocalized(values, 'bo'), 'Tibetan');
      expect(pickLocalized(const {'fr': 'Tibétain'}, 'bo'), 'Tibétain');
      expect(pickLocalized(const {}, 'en'), '');
    });
  });

  group('getChantRecordings', () {
    test('lists the edition\'s recordings, then the text\'s others', () async {
      final server = LibraryTestServer({
        '/v2/editions/ed-1':
            (_) => jsonBody({'id': 'ed-1', 'text_id': 'text-1'}),
        '/v2/editions/ed-1/recordings': (_) => jsonBody([_recording('rec-1')]),
        '/v2/texts/text-1':
            (_) => jsonBody({
              'id': 'text-1',
              'title': {'bo': 'x'},
              'language': 'bo',
              'audios': ['aud-1', 'aud-2'],
            }),
        '/v2/audios/aud-2/recordings':
            (_) => jsonBody([
              _recording('rec-2', audioId: 'aud-2', editionId: 'ed-other'),
              // Listed twice by the server: kept once.
              _recording('rec-1'),
            ]),
      });
      final repo = server.repository();

      final recordings = await repo.getChantRecordings('ed-1');
      expect(recordings.map((r) => r.id), ['rec-1', 'rec-2']);
      // aud-1 is already covered by the edition's own recording.
      expect(server.count('/v2/audios/aud-1/recordings'), 0);

      await repo.getChantRecordings('ed-1');
      expect(server.count('/v2/editions/ed-1/recordings'), 1);
    });

    test('a chant with no recordings reads as an empty list', () async {
      final server = LibraryTestServer({
        '/v2/editions/ed-1':
            (_) => jsonBody({'id': 'ed-1', 'text_id': 'text-1'}),
        '/v2/editions/ed-1/recordings': (_) => jsonBody(const []),
        '/v2/texts/text-1':
            (_) => jsonBody({
              'id': 'text-1',
              'title': {'zh': 'x'},
              'language': 'zh',
              'audios': const [],
            }),
      });
      final repo = server.repository();

      expect(await repo.getChantRecordings('ed-1'), isEmpty);
      expect(await repo.hasChantRecordings('ed-1'), isFalse);
    });

    test('hasChantRecordings reads the text\'s performances', () async {
      final server = LibraryTestServer({
        '/v2/editions/ed-1':
            (_) => jsonBody({'id': 'ed-1', 'text_id': 'text-1'}),
        '/v2/texts/text-1':
            (_) => jsonBody({
              'id': 'text-1',
              'title': {'bo': 'x'},
              'language': 'bo',
              'audios': ['aud-1'],
            }),
      });
      final repo = server.repository();

      expect(await repo.hasChantRecordings('ed-1'), isTrue);
      expect(server.count('/v2/editions/ed-1/recordings'), 0);
      // An unknown chant counts as none instead of failing the list.
      expect(await repo.hasChantRecordings('missing'), isFalse);
    });

    test('getRecordingAudioUrl asks again every time', () async {
      var served = 0;
      final server = LibraryTestServer({
        '/v2/recordings/rec-1/audio-url':
            (_) => jsonBody({
              'url': 'https://s3/rec-1?sig=${++served}',
              'expires_in': 3600,
            }),
      });
      final repo = server.repository();

      expect(await repo.getRecordingAudioUrl('rec-1'), endsWith('sig=1'));
      expect(await repo.getRecordingAudioUrl('rec-1'), endsWith('sig=2'));
    });
  });

  group('datasource', () {
    late List<RequestOptions> sent;
    late LibraryRemoteDatasource datasource;

    setUp(() {
      sent = [];
      final dio = Dio(BaseOptions(baseUrl: 'https://library.test'));
      dio.httpClientAdapter = FakeHttpAdapter((options) async {
        sent.add(options);
        return switch (options.uri.path) {
          '/v2/recordings/rec-1/audio-url' => jsonBody({
            'url': 'https://s3/rec-1?sig',
            'expires_in': 3600,
          }),
          '/v2/texts/text-1/audios' => jsonBody([
            {
              'id': 'aud-1',
              'title': {'en': 'Sung'},
              'recordings': ['rec-1'],
            },
          ]),
          _ => jsonBody([_recording('rec-1')]),
        };
      });
      datasource = LibraryRemoteDatasource(dio: dio);
    });

    test('calls each recordings endpoint', () async {
      expect(
        (await datasource.fetchEditionRecordings('ed-1')).single.id,
        'rec-1',
      );
      expect(
        (await datasource.fetchAudioRecordings('aud-1')).single.id,
        'rec-1',
      );
      expect((await datasource.fetchTextAudios('text-1')).single.recordingIds, [
        'rec-1',
      ]);
      expect(sent.map((o) => o.uri.path), [
        '/v2/editions/ed-1/recordings',
        '/v2/audios/aud-1/recordings',
        '/v2/texts/text-1/audios',
      ]);
      // Recording lists may come from the HTTP cache.
      expect(sent.every((o) => o.extra['no_cache'] != true), isTrue);
    });

    test('the audio link always skips the HTTP cache', () async {
      final link = await datasource.fetchRecordingAudioUrl('rec-1');
      expect(link.url, 'https://s3/rec-1?sig');
      expect(sent.single.extra['no_cache'], isTrue);
    });

    test('a payload of the wrong shape is a format error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://library.test'));
      dio.httpClientAdapter = FakeHttpAdapter(
        (_) async => jsonBody({'detail': 'not a list'}),
      );
      final broken = LibraryRemoteDatasource(dio: dio);
      expect(
        () => broken.fetchEditionRecordings('ed-1'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('more repository cases', () {
    test('LibraryText reads its performances from audios', () {
      final text = LibraryText.fromJson({
        'id': 'text-1',
        'title': {'bo': 'x'},
        'language': 'bo',
        'audios': ['aud-1', 'aud-2'],
      });
      expect(text.audioIds, ['aud-1', 'aud-2']);
      expect(
        LibraryText.fromJson({
          'id': 't',
          'title': {},
          'language': 'bo',
        }).audioIds,
        isEmpty,
      );
    });

    test('an older text id resolves to its first edition', () async {
      final server = LibraryTestServer({
        '/v2/texts/text-1':
            (_) => jsonBody({
              'id': 'text-1',
              'title': {'bo': 'x'},
              'language': 'bo',
              'editions': ['ed-1'],
              'audios': ['aud-1'],
            }),
        '/v2/editions/ed-1':
            (_) => jsonBody({'id': 'ed-1', 'text_id': 'text-1'}),
        '/v2/editions/ed-1/recordings': (_) => jsonBody([_recording('rec-1')]),
      });
      final repo = server.repository();

      final recordings = await repo.getChantRecordings('text-1');
      expect(recordings.single.id, 'rec-1');
      expect(await repo.hasChantRecordings('text-1'), isTrue);
    });

    test('an edition with no list of its own uses the text\'s', () async {
      final server = LibraryTestServer({
        '/v2/editions/ed-1':
            (_) => jsonBody({'id': 'ed-1', 'text_id': 'text-1'}),
        // No /recordings route: the server answers 404.
        '/v2/texts/text-1':
            (_) => jsonBody({
              'id': 'text-1',
              'title': {'bo': 'x'},
              'language': 'bo',
              'audios': ['aud-1'],
            }),
        '/v2/audios/aud-1/recordings':
            (_) => jsonBody([_recording('rec-9', editionId: 'ed-other')]),
      });
      final repo = server.repository();

      final recordings = await repo.getChantRecordings('ed-1');
      expect(recordings.single.id, 'rec-9');
      expect(recordings.single.editionId, 'ed-other');
    });

    test('an unknown chant fails the lookup and is retried later', () async {
      final server = LibraryTestServer({});
      final repo = server.repository();

      await expectLater(repo.getChantRecordings('missing'), throwsA(anything));
      await expectLater(repo.getChantRecordings('missing'), throwsA(anything));
      expect(server.count('/v2/editions/missing'), 2);
    });

    test('a server error on the list is not hidden as no recordings', () async {
      final server = LibraryTestServer({
        '/v2/editions/ed-1':
            (_) => jsonBody({'id': 'ed-1', 'text_id': 'text-1'}),
        '/v2/editions/ed-1/recordings':
            (_) => jsonBody({'detail': 'boom'}, statusCode: 500),
      });
      final repo = server.repository();

      await expectLater(repo.getChantRecordings('ed-1'), throwsA(anything));
    });

    test('getTextAudios lists performances, none when unknown', () async {
      final server = LibraryTestServer({
        '/v2/texts/text-1/audios':
            (_) => jsonBody([
              {
                'id': 'aud-1',
                'title': {'en': 'Sung'},
                'recordings': ['rec-1'],
              },
            ]),
      });
      final repo = server.repository();

      expect((await repo.getTextAudios('text-1')).single.id, 'aud-1');
      expect(await repo.getTextAudios('missing'), isEmpty);
    });

    test('an empty audio link is an error, not a blank url', () async {
      final server = LibraryTestServer({
        '/v2/recordings/rec-1/audio-url': (_) => jsonBody({'url': ' '}),
      });
      await expectLater(
        server.repository().getRecordingAudioUrl('rec-1'),
        throwsA(anything),
      );
    });
  });
}
