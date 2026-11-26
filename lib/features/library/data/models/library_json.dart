/// Lenient JSON helpers for library API payloads.
List<String> stringListFromJson(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList(growable: false);
}

Map<String, String> stringMapFromJson(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

/// The value for [language] (compared on the main tag, so `zh` matches
/// `zh-Hant`), else English, else the first one, else empty.
String pickLocalized(Map<String, String> values, String? language) {
  String main(String code) => code.toLowerCase().split(RegExp('[-_]')).first;
  final wanted = language == null ? '' : main(language);
  if (wanted.isNotEmpty) {
    for (final entry in values.entries) {
      if (main(entry.key) == wanted && entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
  }
  final english = values['en']?.trim();
  if (english != null && english.isNotEmpty) return english;
  for (final value in values.values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
