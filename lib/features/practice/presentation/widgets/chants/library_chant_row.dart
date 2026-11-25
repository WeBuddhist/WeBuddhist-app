import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';

/// A chant from the library catalogue. One the library has recorded shows
/// as an [AudioChantRow], like a space chant with recordings: the row opens
/// it, the play button opens it playing. Any other is a [TextChantRow].
class LibraryChantRow extends StatelessWidget {
  const LibraryChantRow({
    super.key,
    required this.chant,
    required this.onOpen,
  });

  final RecitationModel chant;

  /// Opens the chant; `play` is true from the play button.
  final void Function({required bool play}) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (chant.hasAudio) {
      return AudioChantRow(
        title: chant.title,
        language: chant.language,
        playLabel: l10n.player_play,
        imageUrl: chant.imageUrl,
        onTap: () => onOpen(play: false),
        onPlay: () => onOpen(play: true),
      );
    }
    return TextChantRow(
      title: chant.title,
      openLabel: l10n.chants_open_chant,
      language: chant.language,
      firstVerse: chant.firstSegment?.content,
      onTap: () => onOpen(play: false),
    );
  }
}
