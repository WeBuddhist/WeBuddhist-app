import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/library/data/datasource/library_remote_datasource.dart';
import 'package:flutter_pecha/features/library/data/models/library_recording.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../library_test_server.dart';

/// A recording as `GET /v2/editions/{id}/recordings` serves it (dev library).
Map<String, dynamic> _recordingJson(
  String id, {
  String? editionId = 'E1',
  Object? title = const {'en': 'Recitation'},
}) => {
  'title': title,
  'duration_ms': 601541,
  'id': id,
  'audio_id': 'A1',
  'text_id': 'T1',
  'edition_id': editionId,
  'format': 'm4a',
  'size_bytes': 9738652,
};

void main() {
  group('LibraryRecording.fromJson', () {
    test('reads the recording fields', () {
      final recording = LibraryRecording.fromJson(_recordingJson('R1'));

      expect(recording.id, 'R1');
      expect(recording.audioId, 'A1');
      expect(recording.textId, 'T1');
      expect(recording.editionId, 'E1');
      expect(recording.durationMs, 601541);
      expect(recording.format, 'm4a');
      expect(recording.title, {'en': 'Recitation'});
    });

    test('a missing or blank edition is null', () {
      expect(
        LibraryRecording.fromJson(
          _recordingJson('R1', editionId: null),
        ).editionId,
        isNull,
      );
      expect(
        LibraryRecording.fromJson(
          _recordingJson('R1', editionId: ' '),
        ).editionId,
        isNull,
      );
    });

    test('displayTitle prefers the language, then English, then any', () {
      final recording = LibraryRecording.fromJson(
        _recordingJson('R1', title: {'bo': 'གསུང་', 'en': 'Recitation'}),
      );
      final tibetanOnly = LibraryRecording.fromJson(
        _recordingJson('R2', title: {'bo': 'གསུང་', 'en': ' '}),
      );
      final untitled = LibraryRecording.fromJson(
        _recordingJson('R3', title: null),
      );

      expect(recording.displayTitle('bo'), 'གསུང་');
      expect(recording.displayTitle('zh'), 'Recitation');
      expect(tibetanOnly.displayTitle('zh'), 'གསུང་');
      expect(untitled.displayTitle('en'), '');
    });
  });

  group('LibraryRecordingAudioUrl.fromJson', () {
    test('reads the link and its lifetime', () {
      final link = LibraryRecordingAudioUrl.fromJson({
        'url': ' https://files.test/r1.m4a?sig=1 ',
        'expires_in': 3600,
      });

      expect(link.url, 'https://files.test/r1.m4a?sig=1');
      expect(link.expiresIn, const Duration(hours: 1));
    });
  });

  group('LibraryRemoteDatasource recordings', () {
    test('asks for a link without the HTTP cache', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://library.test'));
      dio.httpClientAdapter = FakeHttpAdapter((options) async {
        requests.add(options);
        return jsonBody({'url': 'https://files.test/r1', 'expires_in': 60});
      });

      final link = await LibraryRemoteDatasource(
        dio: dio,
      ).fetchRecordingAudioUrl('R1');

      expect(link.url, 'https://files.test/r1');
      expect(requests.single.path, '/v2/recordings/R1/audio-url');
      expect(requests.single.extra['no_cache'], isTrue);
    });
  });

  group('LibraryRepository recordings', () {
    LibraryTestServer server() => LibraryTestServer({
      '/v2/editions/E1': (_) => jsonBody({'id': 'E1', 'text_id': 'T1'}),
      '/v2/texts/T1': (_) => jsonBody(textJson('T1', editions: ['E1'])),
      '/v2/editions/E1/recordings':
          (_) => jsonBody([
            _recordingJson('R1'),
            _recordingJson(''),
            _recordingJson('R2'),
          ]),
      '/v2/recordings/R1/audio-url':
          (_) => jsonBody({'url': 'https://files.test/r1', 'expires_in': 60}),
    });

    test('lists the edition recordings once per edition', () async {
      final s = server();
      final repository = s.repository();

      final first = await repository.getEditionRecordings('E1');
      await repository.getEditionRecordings('E1');

      expect(first.map((r) => r.id), ['R1', 'R2']);
      expect(s.count('/v2/editions/E1/recordings'), 1);
    });

    test('a text id lists its first edition recordings', () async {
      final s = server();

      final recordings = await s.repository().getEditionRecordings('T1');

      expect(recordings.map((r) => r.id), ['R1', 'R2']);
      expect(s.count('/v2/editions/E1/recordings'), 1);
    });

    test('an edition without recordings has none', () async {
      final s = LibraryTestServer({
        '/v2/editions/E2': (_) => jsonBody({'id': 'E2', 'text_id': 'T2'}),
        '/v2/editions/E2/recordings': (_) => jsonBody([]),
      });

      expect(await s.repository().getEditionRecordings('E2'), isEmpty);
    });

    test('a failed lookup is asked again next time', () async {
      var calls = 0;
      final s = LibraryTestServer({
        '/v2/editions/E1': (_) => jsonBody({'id': 'E1', 'text_id': 'T1'}),
        '/v2/editions/E1/recordings': (_) {
          calls++;
          return calls == 1
              ? jsonBody({'detail': 'down'}, statusCode: 500)
              : jsonBody([_recordingJson('R1')]);
        },
      });
      final repository = s.repository();

      await expectLater(
        repository.getEditionRecordings('E1'),
        throwsA(isA<Object>()),
      );
      final recordings = await repository.getEditionRecordings('E1');

      expect(recordings.single.id, 'R1');
      expect(calls, 2);
    });

    test('every link request reaches the server', () async {
      final s = server();
      final repository = s.repository();

      final link = await repository.getRecordingAudioUrl('R1');
      await repository.getRecordingAudioUrl('R1');

      expect(link.url, 'https://files.test/r1');
      expect(s.count('/v2/recordings/R1/audio-url'), 2);
    });
  });
}
