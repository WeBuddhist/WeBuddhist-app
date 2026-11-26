import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/l10n/intl_format_locale.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/home/domain/entities/verse_of_day.dart';
import 'package:flutter_pecha/features/home/presentation/utils/verse_of_day_labels.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_comments_sheet.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_of_day_content.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_of_day_engagement_bar.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_share_sheet.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fixed height of a verse card, from the Figma frame (390 wide).
const double verseOfDayCardHeight = 420;

/// One day's verse: full-bleed image with the date pill, the verse, its
/// source and like / comment / share laid over a dark fade at the bottom.
/// Tapping it opens the share sheet.
class VerseOfDayCard extends ConsumerStatefulWidget {
  const VerseOfDayCard({super.key, required this.verseOfDay, DateTime? now})
    : _now = now;

  final VerseOfDay verseOfDay;

  /// Pins "today" for the date pill; the device clock when null.
  final DateTime? _now;

  @override
  ConsumerState<VerseOfDayCard> createState() => _VerseOfDayCardState();
}

class _VerseOfDayCardState extends ConsumerState<VerseOfDayCard> {
  static const _onImage = AppColors.surfaceWhite;

  /// Tibetan wraps into more, shorter lines, so it gets one more.
  static const _maxVerseLines = 3;
  static const _maxTibetanVerseLines = 4;

  final GlobalKey _shareIconKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _onShareTap() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);
    await shareVerseOfDayQuote(
      context,
      verseOfDay: widget.verseOfDay,
      shareOriginKey: _shareIconKey,
    );
    if (mounted) setState(() => _isSharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final verse = widget.verseOfDay;
    final languageCode = ref.watch(localeProvider).languageCode;
    final isTibetan = AppFontConfig.isTibetanLanguage(languageCode);
    final typography = VerseOfDayTypography.forCard(
      languageCode,
      verseFontSize: getLocalizedFontSize(AppTextSize.content),
      attributionFontSize: getLocalizedFontSize(AppTextSize.body),
    );
    final dateLabel = verseOfDayDateLabel(
      date: verse.date,
      now: widget._now ?? DateTime.now(),
      todayLabel: context.l10n.home_today,
      intlLocale: intlFormatLocaleOf(context),
      useTibetanDigits: isTibetan,
    );

    var verseStyle = typography.verseTextStyle(color: _onImage);
    if (!typography.useGoogleJomolhari) {
      verseStyle = verseStyle.copyWith(height: 1.45);
    }
    verseStyle = verseStyle.copyWith(shadows: _textShadows);

    return SizedBox(
      height: verseOfDayCardHeight,
      child: Material(
        color: Colors.black,
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => showVerseShareSheet(context, verse),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImageWidget(
                imageUrl: verse.imageUrl,
                fallbackAsset: AppAssets.verseOfDayFallback,
                fit: BoxFit.cover,
                width: double.infinity,
                height: verseOfDayCardHeight,
              ),
              const _BottomFade(),
              if (dateLabel.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 14,
                  child: _DatePill(label: dateLabel),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      withTibetanLineBreakOpportunities(verse.verse),
                      maxLines:
                          isTibetan ? _maxTibetanVerseLines : _maxVerseLines,
                      overflow: TextOverflow.ellipsis,
                      strutStyle: context.tibetanStrutStyle(
                        typography.verseFontSize,
                      ),
                      style: verseStyle,
                    ),
                    if (verse.source.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SourceRow(source: verse.source, typography: typography),
                    ],
                    const SizedBox(height: 6),
                    VerseOfDayEngagementBar(
                      verseId: verse.id,
                      foregroundColor: _onImage,
                      trailingAtEnd: false,
                      onCommentTap:
                          () => VerseCommentsSheet.show(
                            context,
                            verseId: verse.id,
                          ),
                      trailing: _ShareButton(
                        key: _shareIconKey,
                        isSharing: _isSharing,
                        onTap: _onShareTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _textShadows = [
  Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 1)),
];

/// Darkens the lower part of the image so white text reads on any photo.
class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.3, 0.65, 1],
            colors: [Color(0x00000000), Color(0x73000000), Color(0xB3000000)],
          ),
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const fontSize = 13.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          strutStyle: context.tibetanStrutStyle(fontSize, compact: true),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.typography});

  final String source;
  final VerseOfDayTypography typography;

  @override
  Widget build(BuildContext context) {
    final fontSize = typography.attributionFontSize;
    return Row(
      children: [
        Icon(
          AppAssets.bookOpen,
          size: fontSize + 4,
          color: AppColors.surfaceWhite,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            withTibetanLineBreakOpportunities(source),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: context.tibetanStrutStyle(fontSize),
            style: typography
                .attributionTextStyle(
                  color: AppColors.surfaceWhite,
                  useContentFontForAttribution:
                      typography.useContentFontForAttribution,
                  fontWeight: FontWeight.w400,
                )
                .copyWith(shadows: _textShadows),
          ),
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    super.key,
    required this.isSharing,
    required this.onTap,
  });

  final bool isSharing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSharing ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 32,
        child:
            isSharing
                ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                )
                : const Icon(
                  AppAssets.readerShare,
                  color: AppColors.surfaceWhite,
                  size: 22,
                ),
      ),
    );
  }
}
