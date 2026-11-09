import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ConnectCommentsSkeleton extends StatelessWidget {
  const ConnectCommentsSkeleton({
    super.key,
    this.showPostPreview = false,
    this.postCard,
  });

  final bool showPostPreview;
  final Widget? postCard;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, showPostPreview ? 0 : 8, 20, 16),
        children: [
          if (showPostPreview && postCard != null) ...[
            postCard!,
            const SizedBox(height: 24),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Bone.text(words: 2, fontSize: 18),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < 6; i++) ...[
            _buildCommentSkeletonItem(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentSkeletonItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Bone.circle(size: 32),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 2, fontSize: 14),
                const SizedBox(height: 4),
                Bone.text(words: 1, fontSize: 11),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Bone.text(words: 8, fontSize: 14),
              const SizedBox(height: 4),
              Bone.text(words: 5, fontSize: 14),
            ],
          ),
        ),
      ],
    );
  }
}
