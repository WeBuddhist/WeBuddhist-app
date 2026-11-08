import 'package:flutter_pecha/features/onboarding/data/models/tradition_models.dart';

/// The library tags that narrow the chant list to [selectedCodes].
///
/// Empty means "do not filter": nothing selected, every tagged tradition
/// selected ("show me everything"), or no tradition in [catalog] has a tag
/// yet. Traditions without a tag cannot filter and are ignored. Order follows
/// the catalogue so the result is stable for cache keys.
List<String> resolveTraditionTagIds({
  required List<Tradition> catalog,
  required Set<String> selectedCodes,
}) {
  final tagged = [
    for (final tradition in catalog)
      if (tradition.libraryTagId case final tagId?) (tradition.code, tagId),
  ];
  if (tagged.isEmpty) return const [];
  final selected = [
    for (final (code, tagId) in tagged)
      if (selectedCodes.contains(code)) tagId,
  ];
  if (selected.isEmpty || selected.length == tagged.length) return const [];
  return List.unmodifiable(selected);
}
