import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chant_display.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_actions.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';

/// A space chant with recordings as an [AudioChantRow]: the row opens the
/// chant, the button opens it playing the first recording.
class SpaceAudioChantRow extends StatelessWidget {
  const SpaceAudioChantRow({super.key, required this.chant});

  final SpaceChant chant;

  @override
  Widget build(BuildContext context) {
    final item = chant.item;
    final audio = item.audio.isEmpty ? null : item.audio.first;
    return AudioChantRow(
      title: item.title,
      language: item.language,
      playLabel: context.l10n.player_play,
      reciterLine: chantReciterLine(
        reciterName: audio?.reciterName,
        audioTitle: audio?.title,
      ),
      imageUrl: chantArtworkUrl(
        audioImageUrl: audio?.imageUrl,
        collectionImageUrl: chant.collection.imageUrl,
        groupAvatarUrl: chant.groupAvatarUrl,
      ),
      onTap: () => openSpaceChant(context, chant),
      onPlay: () => openSpaceChant(context, chant, play: true),
    );
  }
}

/// A space chant without recordings as a [TextChantRow]. Chant book items
/// carry no verse, so there is no preview line.
class SpaceTextChantRow extends StatelessWidget {
  const SpaceTextChantRow({super.key, required this.chant});

  final SpaceChant chant;

  @override
  Widget build(BuildContext context) {
    return TextChantRow(
      title: chant.item.title,
      language: chant.item.language,
      openLabel: context.l10n.chants_open_chant,
      onTap: () => openSpaceChant(context, chant),
    );
  }
}
