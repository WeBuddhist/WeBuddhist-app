import 'package:flutter_pecha/features/library/data/models/library_json.dart';

/// One audio file of a performance, from `/v2/editions/{id}/recordings` or
/// `/v2/audios/{id}/recordings`. A recording with an [editionId] follows that
/// edition's text, so its cues can highlight that edition's verses.
class LibraryRecording {
  final String id;
  final Map<String, String> title;
  final int? durationMs;
  final String? audioId;
  final String? textId;
  final String? editionId;
  final String? format;

  const LibraryRecording({
    required this.id,
    this.title = const {},
    this.durationMs,
    this.audioId,
    this.textId,
    this.editionId,
    this.format,
  });

  factory LibraryRecording.fromJson(Map<String, dynamic> json) {
    return LibraryRecording(
      id: json['id'] as String,
      title: stringMapFromJson(json['title']),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      audioId: json['audio_id'] as String?,
      textId: json['text_id'] as String?,
      editionId: json['edition_id'] as String?,
      format: json['format'] as String?,
    );
  }

  /// Title in [language], else English, else any title, else empty.
  String titleIn(String? language) => pickLocalized(title, language);
}

/// A performance of a text, from `/v2/texts/{id}/audios`: its title,
/// language, performers and the ids of its [recordingIds].
class LibraryAudio {
  final String id;
  final Map<String, String> title;
  final String? language;
  final String? textId;
  final List<String> performerNames;
  final List<String> recordingIds;

  const LibraryAudio({
    required this.id,
    this.title = const {},
    this.language,
    this.textId,
    this.performerNames = const [],
    this.recordingIds = const [],
  });

  factory LibraryAudio.fromJson(Map<String, dynamic> json) {
    final contributions = json['contributions'];
    return LibraryAudio(
      id: json['id'] as String,
      title: stringMapFromJson(json['title']),
      language: json['language'] as String?,
      textId: json['text_id'] as String?,
      performerNames: [
        if (contributions is List)
          for (final c in contributions.whereType<Map<String, dynamic>>())
            if (pickLocalized(stringMapFromJson(c['name']), null)
                case final name when name.isNotEmpty)
              name,
      ],
      recordingIds: stringListFromJson(json['recordings']),
    );
  }

  String titleIn(String? language) => pickLocalized(title, language);
}

/// `GET /v2/recordings/{id}/audio-url`: a presigned [url] any player can
/// open without an API key, valid for [expiresIn] seconds.
class LibraryAudioUrl {
  final String url;
  final int? expiresIn;

  const LibraryAudioUrl({required this.url, this.expiresIn});

  factory LibraryAudioUrl.fromJson(Map<String, dynamic> json) {
    return LibraryAudioUrl(
      url: (json['url'] as String? ?? '').trim(),
      expiresIn: (json['expires_in'] as num?)?.toInt(),
    );
  }
}
