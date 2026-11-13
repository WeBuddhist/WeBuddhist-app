import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/utils/tibetan_numerals.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_text.dart';

/// A chant book on the Chants page: square cover with a chant-count badge
/// and, when it has recordings, an audio mark; name and owner below.
///
/// [width] is the cover size; the horizontal rail uses
/// [ChantBookCard.railWidth], See-all grids pass their cell width.
class ChantBookCard extends StatelessWidget {
  const ChantBookCard({
    super.key,
    required this.name,
    required this.chantCount,
    this.subtitle,
    this.imageUrl,
    this.hasAudio = false,
    this.width = railWidth,
    this.onTap,
  });

  final String name;
  final int chantCount;

  /// Space name, or the owner for a personal book.
  final String? subtitle;
  final String? imageUrl;
  final bool hasAudio;
  final double width;
  final VoidCallback? onTap;

  static const double railWidth = 170;
  static const double _radius = 8;

  /// Room the name and subtitle need under the cover at the device's text
  /// size: gap (8), a Tibetan-height 15pt title (~29 at 1x), gap (2) and
  /// the 12pt subtitle (~16 at 1x). Font sizes go through the text scaler,
  /// so nonlinear scaling grows each line as the text itself grows.
  static double textHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 8 + scaler.scale(15) * 29 / 15 + 2 + scaler.scale(12) * 16 / 12;
  }

  /// Height of a rail of cards at [railWidth], with a little slack.
  static double railHeight(BuildContext context) =>
      railWidth + textHeight(context) + 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleText = subtitle?.trim() ?? '';

    return SizedBox(
      width: width,
      child: Semantics(
        button: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: width,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CachedNetworkImageWidget(
                        imageUrl: imageUrl,
                        fallbackAsset: AppAssets.myCollectionDefault,
                        width: width,
                        height: width,
                        borderRadius: BorderRadius.circular(_radius),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _CountBadge(count: chantCount, isDark: isDark),
                    ),
                    if (hasAudio)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: _AudioMark(isDark: isDark),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ChantContentText(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitleText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.isDark});

  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.my_recitation_collection_chant_count(count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.backgroundDark.withAlpha(190)
                : AppColors.surfaceWhite.withAlpha(230),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.isTibetanLocale ? toTibetanDigits(label) : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _AudioMark extends StatelessWidget {
  const _AudioMark({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isDark
                ? AppColors.backgroundDark.withAlpha(190)
                : AppColors.surfaceWhite.withAlpha(230),
      ),
      alignment: Alignment.center,
      child: Icon(
        AppAssets.chantAudio,
        size: 16,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
      ),
    );
  }
}
