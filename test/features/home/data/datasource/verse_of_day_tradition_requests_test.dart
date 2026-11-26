import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/home/data/datasource/home_local_datasource.dart';
import 'package:flutter_pecha/features/home/data/datasource/verse_of_day_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'verse_of_day': null}),
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
  late VerseOfDayRemoteDatasource remote;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    remote = VerseOfDayRemoteDatasource(dio: dio);
  });

  group('VerseOfDayRemoteDatasource tradition', () {
    test('today and by-date send the tradition when given', () async {
      await remote.fetchVerseOfDay(language: 'en', tradition: 'pali');
      await remote.fetchVerseOfDayByDate(
        language: 'en',
        date: '2026-11-24',
        tradition: 'pali',
      );

      expect(adapter.requests.map((r) => r.queryParameters['tradition']), [
        'pali',
        'pali',
      ]);
    });

    test('no tradition leaves the param out', () async {
      await remote.fetchVerseOfDay(language: 'en');
      await remote.fetchVerseOfDayByDate(language: 'en', date: '2026-11-24');

      for (final request in adapter.requests) {
        expect(request.queryParameters.containsKey('tradition'), isFalse);
      }
    });

    test('a day with no verse for the tradition is null', () async {
      expect(
        await remote.fetchVerseOfDay(language: 'en', tradition: 'tibetan'),
        isNull,
      );
    });
  });

  group('HomeLocalDatasource verse keys', () {
    final local = HomeLocalDatasource();

    test('each tradition has its own keys', () {
      expect(
        local.verseOfDayKey('en', tradition: 'pali'),
        isNot(local.verseOfDayKey('en', tradition: 'tibetan')),
      );
      expect(
        local.recentVerseDatesKey('en', tradition: 'pali'),
        isNot(local.recentVerseDatesKey('en')),
      );
      expect(
        local.verseOfDayByDateKey('en', '2026-11-24', tradition: 'pali'),
        startsWith(local.verseOfDayByDatePrefix('en', tradition: 'pali')),
      );
    });

    test('keys moved off the v1 ones, which were not per tradition', () {
      expect(local.verseOfDayKey('en'), isNot('verse_of_day:en'));
      expect(local.recentVerseDatesKey('en'), isNot('verse_of_day_recent:en'));
    });
  });
}
