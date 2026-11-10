import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class PrayerRequestsSkeleton extends StatelessWidget {
  const PrayerRequestsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Hosts such as the prayer sheet size this to whatever height is left,
    // which can be less than three cards; clip instead of overflowing.
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < 3; i++) ...[
              _buildPrayerRequestSkeletonItem(context),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRequestSkeletonItem(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Bone.circle(size: 28),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 2, fontSize: 13),
                    const SizedBox(height: 4),
                    Bone.text(words: 1, fontSize: 11),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Bone.text(words: 10, fontSize: 14),
            const SizedBox(height: 6),
            Bone.text(words: 6, fontSize: 14),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Bone.text(words: 3, fontSize: 12),
                const Spacer(),
                const Bone(
                  width: 50,
                  height: 16,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
