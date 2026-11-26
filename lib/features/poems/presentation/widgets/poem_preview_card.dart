import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/poems/domain/entities/poem.dart';
import 'package:flutter_pecha/features/poems/presentation/utils/poem_share.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One poem in Home's Poems carousel (#1143 design): the cover, the title in
/// the content serif, a gold lotus divider, the opening lines in italic serif
/// fading out, and the author in gold with a share button.
///
/// Tapping the card opens the full-screen poems viewer on this poem.
class PoemPreviewCard extends ConsumerWidget {
  const PoemPreviewCard({super.key, required this.poem, required this.onTap});

  /// Cover frame from the Figma home Poem / Card: 324 × 190.
  static const coverWidth = 324.0;
  static const coverHeight = 190.0;

  static const borderRadius = 12.0;

  /// Room under the cover that doesn't grow with text size: padding, gaps,
  /// the lotus divider, the rule and the share button.
  static const _textAreaFixed = 92.0;

  /// Room under the cover taken by text at 1×: a 2-line title and about
  /// four lines of the poem.
  static const _textAreaText = 132.0;

  /// Room under the cover (224 at 1×). The text part grows with the system
  /// text size so a 2-line title and the author row never clip; the poem
  /// lines take whatever is left.
  static double textAreaHeightFor(TextScaler textScaler) =>
      _textAreaFixed + textScaler.scale(_textAreaText);

  static double coverHeightFor(double width) =>
      width * coverHeight / coverWidth;

  /// Full card height for a card [width] wide, so every cover keeps the
  /// design ratio.
  static double heightFor(double width, TextScaler textScaler) =>
      coverHeightFor(width) + textAreaHeightFor(textScaler);

  final Poem poem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageCode = ref.watch(contentLanguageProvider);
    final isTibetan = AppFontConfig.isTibetanLanguage(languageCode);
    final serif = getFontFamily(languageCode);

    final primaryColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor =
        isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;
    final cardColor =
        isDark ? AppColors.cardBackgroundDark : AppColors.surfaceWhite;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.grey100;
    final placeholderColor =
        isDark ? AppColors.surfaceVariantDark : AppColors.grey100;

    final titleStyle = AppFontConfig.applyTibetanMetrics(
      languageCode,
      TextStyle(
        fontFamily: serif,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        height: 1.3,
      ),
    );
    final linesStyle = AppFontConfig.applyTibetanMetrics(
      languageCode,
      TextStyle(
        fontFamily: serif,
        fontSize: 14,
        // Tibetan has no italic; the serif carries the poem's voice.
        fontStyle: isTibetan ? FontStyle.normal : FontStyle.italic,
        color: primaryColor,
        height: 1.6,
      ),
    );
    final authorStyle = AppFontConfig.applyTibetanMetrics(
      languageCode,
      const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.poemAuthor,
        height: 1.2,
      ),
      compact: true,
    );

    return Material(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: coverWidth / coverHeight,
              child:
                  poem.imageUrl != null && poem.imageUrl!.isNotEmpty
                      ? CachedNetworkImageWidget(
                        imageUrl: poem.imageUrl,
                        fit: BoxFit.cover,
                      )
                      : ColoredBox(
                        color: placeholderColor,
                        child: Icon(
                          AppAssets.bookOpenText,
                          size: 40,
                          color: isDark ? AppColors.grey500 : AppColors.grey600,
                        ),
                      ),
            ),
            SizedBox(
              height: textAreaHeightFor(MediaQuery.textScalerOf(context)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 6, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        poem.title,
                        textAlign: TextAlign.center,
                        style: titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: PoemLotusDivider(),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _FadingLines(
                          text: poem.content.trim(),
                          style: linesStyle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: borderColor,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            poem.authorName,
                            style: authorStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => sharePoem(context, poem),
                          icon: Icon(
                            AppAssets.readerShare,
                            size: 20,
                            color: secondaryColor,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          tooltip: context.l10n.share,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two short gold rules with a lotus between them.
class PoemLotusDivider extends StatelessWidget {
  const PoemLotusDivider({super.key});

  static const _ruleWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final rule = Container(
      width: _ruleWidth,
      height: 1,
      color: AppColors.poemAuthor.withValues(alpha: 0.55),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        rule,
        const SizedBox(width: 6),
        const Icon(AppAssets.poemLotus, size: 16, color: AppColors.poemAuthor),
        const SizedBox(width: 6),
        rule,
      ],
    );
  }
}

/// The poem's opening lines, with their own line breaks, clipped to the
/// space left and fading out toward the bottom instead of ending in `...`.
class _FadingLines extends StatelessWidget {
  const _FadingLines({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback:
            (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Color(0x22000000)],
              stops: [0, 0.45, 1],
            ).createShader(bounds),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(text, style: style),
        ),
      ),
    );
  }
}
