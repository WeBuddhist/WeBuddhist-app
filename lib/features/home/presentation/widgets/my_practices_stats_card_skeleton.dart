import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/my_practices_stats_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// [MyPracticesStatsCard]'s shape while routine info loads.
class MyPracticesStatsCardSkeleton extends StatelessWidget {
  const MyPracticesStatsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Skeletonizer(
        enabled: true,
        child: Material(
          color: AppColors.myPracticesBackground,
          borderRadius: BorderRadius.circular(
            MyPracticesStatsCard.borderRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: const SizedBox(
            height: MyPracticesStatsCard.minHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Bone(width: 120, height: 18),
                  Spacer(),
                  Bone(width: 72, height: 16),
                  SizedBox(width: 10),
                  Bone.circle(size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
