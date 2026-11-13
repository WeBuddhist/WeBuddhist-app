/// Display rules for the Chants page cards and rows, kept free of widgets so
/// they can be tested on their own.
library;

// `characters` comes through the widgets export; it keeps Tibetan stacks
// whole when a preview is cut.
import 'package:flutter/widgets.dart' show StringCharacters;

/// Longest first-verse preview shown under a text-only chant.
const int chantPreviewMaxChars = 120;

/// The first non-blank image: the recording's own, then the chant book's
/// cover, then the space's avatar. Null when none is set.
String? chantArtworkUrl({
  String? audioImageUrl,
  String? collectionImageUrl,
  String? groupAvatarUrl,
}) {
  for (final url in [audioImageUrl, collectionImageUrl, groupAvatarUrl]) {
    final trimmed = url?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

/// The line under an audio chant's title: the reciter when the backend sends
/// one, otherwise the recording's title. Recording titles are often the
/// uploaded file's name ("prayer.mp3"), so an audio file ending is dropped.
/// Null when both are blank.
String? chantReciterLine({String? reciterName, String? audioTitle}) {
  final reciter = reciterName?.trim();
  if (reciter != null && reciter.isNotEmpty) return reciter;
  final title = audioTitle?.trim().replaceFirst(_audioFileEnding, '').trim();
  return title == null || title.isEmpty ? null : title;
}

final RegExp _audioFileEnding = RegExp(
  r'\.(mp3|m4a|aac|wav|ogg|oga|opus|flac|webm)$',
  caseSensitive: false,
);

final RegExp _htmlTag = RegExp(r'<[^>]*>');
final RegExp _whitespace = RegExp(r'\s+');

/// Tibetan tsheg, non-breaking tsheg and shad: places a Tibetan line may
/// break, alongside ordinary spaces.
const Set<String> _breakChars = {' ', '་', '༌', '།'};

/// A one-paragraph preview of a chant's first verse, or null when there is
/// no text.
///
/// Tags are stripped and whitespace collapsed. Text longer than [maxChars]
/// (counted in user-perceived characters) is cut at the last space or tsheg
/// that keeps at least 60% of it, else at [maxChars], and ends with "…".
String? chantPreview(String? text, {int maxChars = chantPreviewMaxChars}) {
  if (text == null) return null;
  final clean =
      text.replaceAll(_htmlTag, ' ').replaceAll(_whitespace, ' ').trim();
  if (clean.isEmpty) return null;

  final chars = clean.characters;
  if (chars.length <= maxChars) return clean;

  final head = chars.take(maxChars).toList();
  var cut = head.length;
  final minCut = (maxChars * 0.6).floor();
  for (var i = head.length - 1; i >= minCut; i--) {
    if (_breakChars.contains(head[i])) {
      // Keep a tsheg or shad on the word it ends; drop a trailing space.
      cut = head[i] == ' ' ? i : i + 1;
      break;
    }
  }
  return '${head.take(cut).join().trimRight()}…';
}
