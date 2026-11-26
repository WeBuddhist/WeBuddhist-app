import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/library/presentation/providers/library_providers.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chant_display.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_actions.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A space chant with recordings as an [AudioChantRow]: the row opens the
/// chant, the button opens it playing the first recording. The line under
/// the title is that library recording's title once it has loaded.
class SpaceAudioChantRow extends ConsumerWidget {
  const SpaceAudioChantRow({super.key, required this.chant, this.onOpened});

  final SpaceChant chant;

  /// Called before the chant opens, from the row or its play button.
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = chant.item;
    final textId = item.textId.trim();
    final recordings = textId.isEmpty
        ? null
        : ref.watch(chantRecordingsProvider(textId)).valueOrNull;
    final first = recordings == null || recordings.isEmpty
        ? null
        : recordings.first;
    return AudioChantRow(
      title: item.title,
      language: item.language,
      playLabel: context.l10n.player_play,
      reciterLine: chantReciterLine(
        audioTitle: first?.titleIn(
          Localizations.localeOf(context).languageCode,
        ),
      ),
      imageUrl: chantArtworkUrl(
        collectionImageUrl: chant.collection.imageUrl,
        groupAvatarUrl: chant.groupAvatarUrl,
      ),
      onTap: () {
        onOpened?.call();
        openSpaceChant(context, chant);
      },
      onPlay: () {
        onOpened?.call();
        openSpaceChant(context, chant, play: true);
      },
    );
  }
}

/// A space chant without recordings as a [TextChantRow]. Chant book items
/// carry no verse, so there is no preview line.
class SpaceTextChantRow extends StatelessWidget {
  const SpaceTextChantRow({super.key, required this.chant, this.onOpened});

  final SpaceChant chant;

  /// Called before the chant opens.
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    return TextChantRow(
      title: chant.item.title,
      language: chant.item.language,
      openLabel: context.l10n.chants_open_chant,
      onTap: () {
        onOpened?.call();
        openSpaceChant(context, chant);
      },
    );
  }
}
