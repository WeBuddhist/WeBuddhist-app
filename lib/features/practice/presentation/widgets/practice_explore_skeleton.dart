import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// The Practice tab while its first load decides the layout: the next
/// session card (signed in only), Mala and Timer, then three rails shaped
/// like plans, chant books and accumulations.
class PracticeExploreSkeleton extends StatelessWidget {
  const PracticeExploreSkeleton({super.key, required this.showNextSession});

  final bool showNextSession;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showNextSession) const _NextSessionBones(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                for (var i = 0; i < 2; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Bone(
                      width: double.infinity,
                      height: 44,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const _Heading(width: 160),
          const _Heading(width: 70, isSubheading: true),
          const _Rail(cardWidth: 300, cardHeight: 220),
          const _Heading(width: 80, isSubheading: true),
          const _Rail(cardWidth: 150, cardHeight: 150),
          const _Heading(width: 120, isSubheading: true),
          const _Rail(cardWidth: 300, cardHeight: 220),
        ],
      ),
    );
  }
}

/// Holds the next session card's place while the routine loads, when the
/// tab last showed one.
class PracticeNextSessionSkeleton extends StatelessWidget {
  const PracticeNextSessionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeletonizer(enabled: true, child: _NextSessionBones());
  }
}

/// Holds "From your spaces"'s place while the joined spaces load, when the
/// tab last showed it.
class PracticeSpacesSkeleton extends StatelessWidget {
  const PracticeSpacesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading(width: 160),
          _Heading(width: 70, isSubheading: true),
          _Rail(cardWidth: 300, cardHeight: 220),
        ],
      ),
    );
  }
}

class _NextSessionBones extends StatelessWidget {
  const _NextSessionBones();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardBackgroundDark : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(width: 130),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Bone.square(size: 48, borderRadius: BorderRadius.circular(10)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(
                        width: 70,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Bone(
                        width: 180,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.width, this.isSubheading = false});

  final double width;
  final bool isSubheading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isSubheading ? 16 : 24, 16, 10),
      child: Bone(
        width: width,
        height: isSubheading ? 16 : 20,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.cardWidth, required this.cardHeight});

  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder:
            (_, _) => Bone(
              width: cardWidth,
              height: cardHeight,
              borderRadius: BorderRadius.circular(12),
            ),
      ),
    );
  }
}
