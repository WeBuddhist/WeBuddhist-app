import 'package:flutter/material.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_of_day_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Placeholder the size of the verse carousel: the fixed-height card, then
/// the page dots' row.
class VerseOfDaySkeleton extends StatelessWidget {
  const VerseOfDaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: verseOfDayCardHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Bone(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(
                        width: double.infinity,
                        height: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 10),
                      Bone(
                        width: 240,
                        height: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 14),
                      Bone(
                        width: 120,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Same height as the dots row, so the page doesn't jump.
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
