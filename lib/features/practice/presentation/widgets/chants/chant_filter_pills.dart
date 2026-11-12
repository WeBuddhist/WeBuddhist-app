import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

/// The Chants page pills: one row, selected one filled black (white in dark
/// mode), the rest white with a hairline border.
class ChantFilterPills extends StatelessWidget {
  const ChantFilterPills({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _ChantFilterPill(
              label: labels[i],
              semanticsHint: localizations.tabLabel(
                tabIndex: i + 1,
                tabCount: labels.length,
              ),
              isSelected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChantFilterPill extends StatelessWidget {
  const _ChantFilterPill({
    required this.label,
    required this.semanticsHint,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String semanticsHint;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final inverse = isDark ? AppColors.textPrimary : AppColors.textPrimaryDark;
    final idleFill =
        isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight;
    final border = isDark ? AppColors.cardBorderDark : AppColors.grey300;

    return Semantics(
      role: SemanticsRole.tab,
      button: true,
      selected: isSelected,
      hint: semanticsHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        // Drawn at the design's 36pt; the tap area is padded to 48.
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    strutStyle: context.tibetanStrutStyle(14, compact: true),
                    style: TextStyle(
                      fontSize: 14,
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
    );
  }
}
