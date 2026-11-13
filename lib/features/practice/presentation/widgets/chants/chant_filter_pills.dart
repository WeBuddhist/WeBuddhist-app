import 'package:flutter/material.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/filter_pill.dart';

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
            // Drawn at the design's 36pt; the tap area is padded to 48.
            FilterPill(
              label: labels[i],
              semanticsHint: localizations.tabLabel(
                tabIndex: i + 1,
                tabCount: labels.length,
              ),
              isSelected: i == selectedIndex,
              onTap: () => onSelected(i),
              fontSize: 14,
              horizontalPadding: 16,
              filledWhenIdle: true,
            ),
          ],
        ],
      ),
    );
  }
}
