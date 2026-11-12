import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chant_display.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_text.dart';

/// White rounded card both chant rows sit in.
class _ChantRowCard extends StatelessWidget {
  const _ChantRowCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color:
          isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

Color _secondaryText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.textTertiaryDark
        : AppColors.textSecondary;

/// A chant with recordings: artwork, title, reciter line and a play button.
/// Tapping the row opens the chant; the button plays it.
class AudioChantRow extends StatelessWidget {
  const AudioChantRow({
    super.key,
    required this.title,
    required this.playLabel,
    this.language,
    this.reciterLine,
    this.imageUrl,
    this.onTap,
    this.onPlay,
  });

  final String title;

  /// Spoken label for the play button.
  final String playLabel;
  final String? language;

  /// From [chantReciterLine].
  final String? reciterLine;

  /// From [chantArtworkUrl].
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  static const double _artSize = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = _secondaryText(context);
    final reciter = reciterLine?.trim() ?? '';

    return _ChantRowCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            CachedNetworkImageWidget(
              imageUrl: imageUrl,
              fallbackAsset: AppAssets.myCollectionDefault,
              width: _artSize,
              height: _artSize,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChantContentText(
                    title,
                    language: language,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (reciter.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          AppAssets.chantAudio,
                          size: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reciter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: secondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ChantCircleButton(
              icon: AppAssets.play,
              iconSize: 14,
              semanticLabel: playLabel,
              onPressed: onPlay,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// A chant without recordings: a bar, the title, a two-line verse preview
/// and an open button.
class TextChantRow extends StatelessWidget {
  const TextChantRow({
    super.key,
    required this.title,
    required this.openLabel,
    this.language,
    this.firstVerse,
    this.onTap,
  });

  final String title;

  /// Spoken label for the open button.
  final String openLabel;
  final String? language;

  /// Raw first verse; trimmed with [chantPreview] here.
  final String? firstVerse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final preview = chantPreview(firstVerse);

    return _ChantRowCard(
      onTap: onTap,
      child: Padding(
        // Room above and below so stacked Tibetan glyphs aren't clipped.
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 10,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.grey600 : AppColors.grey800,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChantContentText(
                      title,
                      language: language,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 4),
                      ChantContentText(
                        preview,
                        language: language,
                        maxLines: 2,
                        isVerse: true,
                        style: TextStyle(
                          // Tibetan reads small at the Latin size.
                          fontSize: chantTextIsTibetan(preview) ? 14 : 12,
                          height: 1.6,
                          color:
                              isDark
                                  ? AppColors.textSubtleDark
                                  : AppColors.grey900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Center(
                child: ChantCircleButton(
                  icon: AppAssets.caretRight,
                  iconSize: 16,
                  semanticLabel: openLabel,
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
