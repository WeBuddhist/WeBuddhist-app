import 'package:flutter_pecha/features/library/data/models/library_json.dart';

/// One audio file of a chant performance (`RecordingOutput`).
///
/// A recording with an [editionId] follows that edition, so it is the one
/// the reader can play for the text on screen.
class LibraryRecording {
  final String id;
  final String audioId;
  final String textId;
  final String? editionId;

  /// Language code to title, e.g. `{"en": "Recitation"}`. May be empty.
  final Map<String, String> title;
  final int? durationMs;

  /// `mp3`, `wav`, `m4a`, `ogg` or `flac`.
  final String format;

  const LibraryRecording({
    required this.id,
    required this.audioId,
    required this.textId,
    required this.title,
    required this.format,
    this.editionId,
    this.durationMs,
  });

  factory LibraryRecording.fromJson(Map<String, dynamic> json) {
    final editionId = (json['edition_id'] as String?)?.trim();
    return LibraryRecording(
      id: (json['id'] as String? ?? '').trim(),
      audioId: json['audio_id'] as String? ?? '',
      textId: json['text_id'] as String? ?? '',
      editionId: editionId == null || editionId.isEmpty ? null : editionId,
      title: stringMapFromJson(json['title']),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      format: json['format'] as String? ?? '',
    );
  }

  /// Title in [language], else English, else any title, else empty.
  String displayTitle(String language) {
    String? clean(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    return clean(title[language]) ??
        clean(title['en']) ??
        title.values.map(clean).whereType<String>().firstOrNull ??
        '';
  }
}

/// A presigned link to a recording's audio (`RecordingAudioUrl`).
///
/// Any player can open [url] without the API key, and it supports seeking.
/// It stops working after [expiresIn], so a player that errors fetches a
/// new one.
class LibraryRecordingAudioUrl {
  final String url;
  final Duration expiresIn;

  const LibraryRecordingAudioUrl({required this.url, required this.expiresIn});

  factory LibraryRecordingAudioUrl.fromJson(Map<String, dynamic> json) {
    return LibraryRecordingAudioUrl(
      url: (json['url'] as String? ?? '').trim(),
      expiresIn: Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 0),
    );
  }
}
