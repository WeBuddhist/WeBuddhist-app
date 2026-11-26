import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/poems_section.dart';
import 'package:flutter_pecha/features/poems/presentation/widgets/poem_preview_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// [PoemsSection] while poems load: the title and one card of the same size,
/// so the feed does not jump when they arrive.
class PoemsSectionSkeleton extends StatelessWidget {
  const PoemsSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? AppColors.cardBackgroundDark : AppColors.surfaceWhite;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.grey100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PoemsSectionTitle(),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = PoemsSection.cardWidthFor(constraints.maxWidth);
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: PoemsSection.horizontalPadding,
                ),
                child: Container(
                  width: cardWidth,
                  height: PoemPreviewCard.heightFor(
                    cardWidth,
                    MediaQuery.textScalerOf(context),
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(
                      PoemPreviewCard.borderRadius,
                    ),
                  ),
                  child: Skeletonizer(
                    enabled: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Bone(
                          width: double.infinity,
                          height: PoemPreviewCard.coverHeightFor(cardWidth),
                          borderRadius: BorderRadius.zero,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            children: [
                              Bone.text(words: 3, fontSize: 16),
                              const SizedBox(height: 16),
                              Bone.text(words: 6, fontSize: 14),
                              const SizedBox(height: 6),
                              Bone.text(words: 5, fontSize: 14),
                              const SizedBox(height: 6),
                              Bone.text(words: 6, fontSize: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
