import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

/// One filter pill, shared by the Bookmarks and Chants screens: the
/// selected pill is filled with the ink colour (black, white in dark mode),
/// the rest have a hairline border.
///
/// Read as a tab. Pass the "Tab 2 of 7" position as [semanticsHint], the
/// way Flutter's [TabBar] reads it, so screen readers know the pills are
/// one set of filters.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.semanticsHint,
    required this.isSelected,
    required this.onTap,
    this.fontSize = 16,
    this.horizontalPadding = 12,
    this.minWidth = 0,
    this.filledWhenIdle = false,
  });

  final String label;
  final String semanticsHint;
  final bool isSelected;
  final VoidCallback onTap;
  final double fontSize;
  final double horizontalPadding;
  final double minWidth;

  /// Gives an unselected pill the card fill instead of a transparent one.
  final bool filledWhenIdle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final inverse = isDark ? AppColors.textPrimary : AppColors.textPrimaryDark;
    final border = isDark ? AppColors.cardBorderDark : AppColors.grey300;
    final idleFill =
        !filledWhenIdle
            ? Colors.transparent
            : isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight;

    // The pill is drawn at the design's height, but like a Material chip its
    // tap area is padded to kMinInteractiveDimension; a tap on that padding
    // selects the pill too.
    return Semantics(
      role: SemanticsRole.tab,
      button: true,
      selected: isSelected,
      hint: semanticsHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Material(
              color: isSelected ? ink : idleFill,
              shape: StadiumBorder(
                side: BorderSide(color: isSelected ? ink : border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 8,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      strutStyle: context.tibetanStrutStyle(
                        fontSize,
                        compact: true,
                      ),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? inverse : ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
