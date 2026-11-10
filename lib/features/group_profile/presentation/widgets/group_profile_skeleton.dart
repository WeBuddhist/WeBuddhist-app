import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class GroupProfileSkeleton extends StatelessWidget {
  const GroupProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const AspectRatio(
                aspectRatio: 3.5,
                child: Bone(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Bone.circle(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone.text(words: 3, fontSize: 18),
                      const SizedBox(height: 6),
                      Bone.text(words: 2, fontSize: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 8, fontSize: 13),
                const SizedBox(height: 6),
                Bone.text(words: 6, fontSize: 13),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Flexible(child: Bone.text(words: 1, fontSize: 16)),
                const SizedBox(width: 32),
                Flexible(child: Bone.text(words: 1, fontSize: 16)),
                const SizedBox(width: 32),
                Flexible(child: Bone.text(words: 1, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1),
        ],
      ),
    );
  }
}
