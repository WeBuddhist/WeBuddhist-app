import 'package:flutter_pecha/features/home/domain/entities/verse_of_day.dart';

class VerseOfDayModel {
  final String id;
  final String verse;
  final String imageUrl;
  final String refId;
  final String refType;
  final String date;
  final String source;
  final String groupTitle;

  VerseOfDayModel({
    required this.id,
    required this.verse,
    required this.imageUrl,
    required this.refId,
    required this.refType,
    required this.date,
    this.source = '',
    this.groupTitle = '',
  });

  /// Parses a `{verse_of_day: {...}}` body, or the bare verse object (the
  /// cached form).
  ///
  /// The text is resolved for [language] here, so the cached copy already
  /// holds the right one: `verse`, else `verses[language]`, else
  /// `verses['en']` (the backend fills the map instead of `verse` when that
  /// translation is missing). An older verse with no source carries it after
  /// a trailing `~` in the text.
  factory VerseOfDayModel.fromJson(
    Map<String, dynamic> json, {
    String language = 'en',
  }) {
    final vodJson = json['verse_of_day'] as Map<String, dynamic>? ?? json;
    final groups =
        (vodJson['group_info'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();

    final text = resolveVerseText(
      verse: vodJson['verse'] as String?,
      verses: vodJson['verses'],
      language: language,
    );
    final split = splitVerseSource(
      text,
      source: resolveVerseText(
        verse: vodJson['source'] as String?,
        verses: vodJson['sources'],
        language: language,
      ),
    );

    return VerseOfDayModel(
      id: (vodJson['id'] as String?) ?? '',
      verse: split.verse,
      imageUrl: (vodJson['image_url'] as String?) ?? '',
      refId: (vodJson['ref_id'] as String?) ?? '',
      refType: (vodJson['ref_type'] as String?) ?? '',
      date: (vodJson['date'] as String?) ?? '',
      source: split.source,
      groupTitle:
          groups.isEmpty ? '' : (groups.first['title'] as String?) ?? '',
    );
  }

  /// Like [VerseOfDayModel.fromJson], but null when the day has no verse:
  /// the body is `{verse_of_day: null}`, or the verse has no id or text.
  static VerseOfDayModel? tryParse(Object? body, {String language = 'en'}) {
    if (body is! Map<String, dynamic>) return null;
    if (body.containsKey('verse_of_day') && body['verse_of_day'] is! Map) {
      return null;
    }
    final model = VerseOfDayModel.fromJson(body, language: language);
    if (model.id.isEmpty || model.verse.isEmpty) return null;
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verse': verse,
      'image_url': imageUrl,
      'ref_id': refId,
      'ref_type': refType,
      'date': date,
      'source': source,
      'group_info': [
        if (groupTitle.isNotEmpty) {'title': groupTitle},
      ],
    };
  }

  VerseOfDay toEntity() {
    return VerseOfDay(
      id: id,
      verse: verse,
      imageUrl: imageUrl,
      date: date,
      source: source,
      groupTitle: groupTitle,
    );
  }
}

/// [verse] when it has text, else [verses] (a language → text map) for
/// [language], else for English. Empty when none has text.
String resolveVerseText({
  required String? verse,
  required Object? verses,
  required String language,
}) {
  final direct = verse?.trim() ?? '';
  if (direct.isNotEmpty) return direct;
  if (verses is! Map) return '';
  for (final key in [language, 'en']) {
    final value = verses[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

/// Splits `text ~ Source` on the last `~` when [source] is empty, as older
/// verses keep their source inside the text. Leaves [text] alone when a
/// source is already given or either side of the `~` would be empty.
/// A given source loses a leading `~` (some are entered as `~Sutra name`).
({String verse, String source}) splitVerseSource(
  String text, {
  String source = '',
}) {
  final cleanSource = source.replaceFirst(RegExp(r'^\s*~\s*'), '');
  if (cleanSource.isNotEmpty) return (verse: text, source: cleanSource);
  final index = text.lastIndexOf('~');
  if (index < 0) return (verse: text, source: '');
  final before = text.substring(0, index).trim();
  final after = text.substring(index + 1).trim();
  if (before.isEmpty || after.isEmpty) return (verse: text, source: '');
  return (verse: before, source: after);
}

/// One cached day of the verse-of-the-day week. [verse] is null for a day
/// with no verse, so it isn't asked for again while the entry is fresh.
class VerseOfDayCacheEntry {
  const VerseOfDayCacheEntry({required this.fetchedAt, this.verse});

  final DateTime fetchedAt;
  final VerseOfDayModel? verse;

  /// `image_url` is a presigned link that expires 24 h after it was issued,
  /// so an entry is fetched again an hour before that.
  static const maxAge = Duration(hours: 23);

  bool isFreshAt(DateTime now) => now.difference(fetchedAt) < maxAge;

  factory VerseOfDayCacheEntry.fromJson(Map<String, dynamic> json) {
    final verse = json['verse'];
    return VerseOfDayCacheEntry(
      fetchedAt:
          DateTime.tryParse(json['fetched_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      verse:
          verse is Map<String, dynamic>
              ? VerseOfDayModel.fromJson(verse)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    'verse': verse?.toJson(),
  };
}
