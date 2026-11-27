import 'package:dio/dio.dart';
import 'package:flutter_pecha/features/library/data/models/library_alignment.dart';
import 'package:flutter_pecha/features/library/data/models/library_edition.dart';
import 'package:flutter_pecha/features/library/data/models/library_language.dart';
import 'package:flutter_pecha/features/library/data/models/library_recording.dart';
import 'package:flutter_pecha/features/library/data/models/library_search_result.dart';
import 'package:flutter_pecha/features/library/data/models/library_segment.dart';
import 'package:flutter_pecha/features/library/data/models/library_text.dart';
import 'package:flutter_pecha/features/library/data/models/library_toc.dart';
import 'package:flutter_pecha/features/library/data/models/library_yigchung.dart';

/// Library (texts) API. Errors are mapped by ErrorInterceptor and propagate.
class LibraryRemoteDatasource {
  LibraryRemoteDatasource({required this.dio});

  final Dio dio;

  /// [title] filters by title and must be at least two characters.
  /// [licenses] keeps texts with any of them; the parameter is repeated.
  Future<LibraryTextPage> fetchTexts({
    required String tagId,
    String? language,
    String? title,
    List<String> licenses = const [],
    int limit = 20,
    int offset = 0,
    bool noCache = false,
  }) async {
    final response = await dio.get(
      '/v2/texts',
      queryParameters: {
        if (language != null && language.isNotEmpty) 'language': language,
        if (title != null && title.isNotEmpty) 'title': title,
        if (licenses.isNotEmpty) 'license': licenses,
        'tag_id': tagId,
        'limit': limit,
        'offset': offset,
      },
      options: Options(
        listFormat: ListFormat.multi,
        extra: noCache ? {'no_cache': true} : null,
      ),
    );
    return LibraryTextPage.fromJson(_asMap(response.data, '/v2/texts'));
  }

  Future<LibraryText> fetchText(String textId) async {
    final response = await dio.get('/v2/texts/$textId');
    return LibraryText.fromJson(_asMap(response.data, '/v2/texts/{id}'));
  }

  Future<LibraryEdition> fetchEdition(String editionId) async {
    final response = await dio.get('/v2/editions/$editionId');
    return LibraryEdition.fromJson(_asMap(response.data, '/v2/editions/{id}'));
  }

  Future<LibrarySegmentPage> fetchEditionSegments(
    String editionId, {
    int limit = 500,
    int offset = 0,
  }) async {
    final response = await dio.get(
      '/v2/editions/$editionId/segmentation/segments',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return LibrarySegmentPage.fromJson(
      _asMap(response.data, '/v2/editions/{id}/segmentation/segments'),
    );
  }

  Future<String> fetchEditionContent(
    String editionId, {
    required int spanStart,
    required int spanEnd,
  }) async {
    final response = await dio.get(
      '/v2/editions/$editionId/content',
      queryParameters: {'span_start': spanStart, 'span_end': spanEnd},
    );
    return _asContent(response.data, '/v2/editions/{id}/content');
  }

  Future<LibraryAlignmentPage> fetchAlignments(
    String sourceEditionId,
    String targetEditionId, {
    int limit = 500,
    int offset = 0,
  }) async {
    final response = await dio.get(
      '/v2/editions/$sourceEditionId/alignments/$targetEditionId',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return LibraryAlignmentPage.fromJson(
      _asMap(response.data, '/v2/editions/{id}/alignments/{id}'),
    );
  }

  Future<List<LibraryTableOfContents>> fetchTableOfContents(
    String editionId,
  ) async {
    final response = await dio.get('/v2/editions/$editionId/table-of-contents');
    return _asList(
      response.data,
      '/v2/editions/{id}/table-of-contents',
    ).map(LibraryTableOfContents.fromJson).toList(growable: false);
  }

  Future<List<LibraryYigchung>> fetchYigchungs(String editionId) async {
    final response = await dio.get('/v2/editions/$editionId/yigchungs');
    return _asList(
      response.data,
      '/v2/editions/{id}/yigchungs',
    ).map(LibraryYigchung.fromJson).toList(growable: false);
  }

  Future<LibrarySegment> fetchSegment(String segmentId) async {
    final response = await dio.get('/v2/segments/$segmentId');
    return LibrarySegment.fromJson(_asMap(response.data, '/v2/segments/{id}'));
  }

  Future<LibrarySegmentPage> fetchRelatedSegments(
    String segmentId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await dio.get(
      '/v2/segments/$segmentId/related',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return LibrarySegmentPage.fromJson(
      _asMap(response.data, '/v2/segments/{id}/related'),
    );
  }

  Future<String> fetchSegmentContent(String segmentId) async {
    final response = await dio.get('/v2/segments/$segmentId/content');
    return _asContent(response.data, '/v2/segments/{id}/content');
  }

  Future<List<LibraryLanguage>> fetchLanguages() async {
    final response = await dio.get('/v2/languages');
    return _asList(
      response.data,
      '/v2/languages',
    ).map(LibraryLanguage.fromJson).toList(growable: false);
  }

  /// Recordings that follow [editionId]; only these can highlight its verses.
  Future<List<LibraryRecording>> fetchEditionRecordings(
    String editionId,
  ) async {
    final response = await dio.get('/v2/editions/$editionId/recordings');
    return _asList(
      response.data,
      '/v2/editions/{id}/recordings',
    ).map(LibraryRecording.fromJson).toList(growable: false);
  }

  /// Every performance of [textId], including ones not linked to an edition.
  Future<List<LibraryAudio>> fetchTextAudios(String textId) async {
    final response = await dio.get('/v2/texts/$textId/audios');
    return _asList(
      response.data,
      '/v2/texts/{id}/audios',
    ).map(LibraryAudio.fromJson).toList(growable: false);
  }

  /// One performance's files.
  Future<List<LibraryRecording>> fetchAudioRecordings(String audioId) async {
    final response = await dio.get('/v2/audios/$audioId/recordings');
    return _asList(
      response.data,
      '/v2/audios/{id}/recordings',
    ).map(LibraryRecording.fromJson).toList(growable: false);
  }

  /// A presigned link to [recordingId]'s file. Never cached: it expires.
  Future<LibraryAudioUrl> fetchRecordingAudioUrl(String recordingId) async {
    final response = await dio.get(
      '/v2/recordings/$recordingId/audio-url',
      options: Options(extra: {'no_cache': true}),
    );
    return LibraryAudioUrl.fromJson(
      _asMap(response.data, '/v2/recordings/{id}/audio-url'),
    );
  }

  Future<List<LibrarySearchResult>> searchContent({
    required String query,
    String? textId,
    String? editionId,
    int limit = 50,
    String searchType = 'exact',
  }) async {
    final response = await dio.get(
      '/v2/content-search',
      queryParameters: {
        'query': query,
        'search_type': searchType,
        'limit': limit,
        if (textId != null) 'text_id': textId,
        if (editionId != null) 'edition_id': editionId,
      },
    );
    return _asList(
      response.data,
      '/v2/content-search',
    ).map(LibrarySearchResult.fromJson).toList(growable: false);
  }

  static Map<String, dynamic> _asMap(Object? data, String endpoint) {
    if (data is Map<String, dynamic>) return data;
    throw FormatException('Unexpected $endpoint payload type');
  }

  static Iterable<Map<String, dynamic>> _asList(Object? data, String endpoint) {
    if (data is List) return data.whereType<Map<String, dynamic>>();
    throw FormatException('Unexpected $endpoint payload type');
  }

  // Content endpoints return a bare JSON string.
  static String _asContent(Object? data, String endpoint) {
    if (data is String) return data;
    if (data is Map<String, dynamic> && data['content'] is String) {
      return data['content'] as String;
    }
    throw FormatException('Unexpected $endpoint payload type');
  }
}
