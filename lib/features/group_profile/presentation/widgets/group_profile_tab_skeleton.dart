import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_profile_nested_tab_scroll_view.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_feed_card_layout.dart';

enum GroupProfileTabSkeletonVariant { feed, event, member }

class GroupProfileTabSkeleton extends StatelessWidget {
  const GroupProfileTabSkeleton({
    super.key,
    this.pageStorageKey,
    required this.variant,
    this.itemCount = 3,
  }) : boxed = false,
       avatarSize = 44;

  /// Same bones, as a short column. For lists that are not a space tab.
  const GroupProfileTabSkeleton.box({
    super.key,
    required this.variant,
    this.itemCount = 3,
    this.avatarSize = 44,
  }) : boxed = true,
       pageStorageKey = null;

  final String? pageStorageKey;
  final GroupProfileTabSkeletonVariant variant;
  final int itemCount;
  final bool boxed;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    if (boxed) {
      return Skeletonizer(
        enabled: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _boxChildren(context),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    EdgeInsets padding;
    Widget sliver;

    switch (variant) {
      case GroupProfileTabSkeletonVariant.feed:
        padding = const EdgeInsets.only(top: 10, bottom: 32);
        sliver = SliverList.separated(
          itemCount: itemCount,
          separatorBuilder:
              (_, __) => ColoredBox(
                color: ConnectFeedCardLayout.listGapColor(isDark),
                child: const SizedBox(height: 10),
              ),
          itemBuilder: (context, index) => _buildFeedSkeletonCard(context),
        );
        break;
      case GroupProfileTabSkeletonVariant.event:
        padding = const EdgeInsets.fromLTRB(16, 8, 16, 32);
        sliver = SliverList.separated(
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildEventSkeletonTile(context),
        );
        break;
      case GroupProfileTabSkeletonVariant.member:
        padding = const EdgeInsets.only(top: 16, bottom: 32);
        sliver = SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Bone.text(words: 2, fontSize: 15),
              );
            }
            return _buildMemberSkeletonRow();
          }, childCount: itemCount + 1),
        );
        break;
    }

    return Skeletonizer(
      enabled: true,
      child: GroupProfileNestedTabScrollView(
        pageStorageKey: pageStorageKey,
        slivers: [SliverPadding(padding: padding, sliver: sliver)],
      ),
    );
  }

  List<Widget> _boxChildren(BuildContext context) {
    return [
      for (var i = 0; i < itemCount; i++) ...[
        switch (variant) {
          GroupProfileTabSkeletonVariant.feed => _buildFeedSkeletonCard(
            context,
          ),
          GroupProfileTabSkeletonVariant.event => _buildEventSkeletonTile(
            context,
          ),
          GroupProfileTabSkeletonVariant.member => _buildMemberSkeletonRow(),
        },
        if (i < itemCount - 1 &&
            variant != GroupProfileTabSkeletonVariant.member)
          const SizedBox(height: 10),
      ],
    ];
  }

  Widget _buildFeedSkeletonCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
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
          const SizedBox(height: 12),
          Bone.text(words: 8, fontSize: 14),
          const SizedBox(height: 4),
          Bone.text(words: 5, fontSize: 14),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const AspectRatio(
              aspectRatio: 1.78,
              child: Bone(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSkeletonTile(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const Bone(
            width: 112,
            height: 112,
            borderRadius: BorderRadius.zero,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Bone.text(words: 3, fontSize: 16),
              const SizedBox(height: 8),
              Bone.text(words: 2, fontSize: 13),
              const SizedBox(height: 6),
              Bone.text(words: 4, fontSize: 13),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberSkeletonRow() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Row(
            children: [
              Bone.circle(size: avatarSize),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 2, fontSize: 15),
                    const SizedBox(height: 4),
                    Bone.text(words: 1, fontSize: 13),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
