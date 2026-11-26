import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_spaces_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_container.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_skeleton.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_space_cards.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_spaces_section.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/space_filter_pills.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accumulations to discover: cards for the accumulations of spaces the
/// user has not joined. Hidden when there are none.
class PracticeAccumulationsSection extends ConsumerWidget {
  const PracticeAccumulationsSection({super.key, this.isSubsection = false});

  /// True under the "Discover more" heading.
  final bool isSubsection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accumulationsAsync = ref.watch(
      practiceSpacePracticesProvider((
        row: PracticeSpaceRow.accumulations,
        joined: false,
      )),
    );

    if (accumulationsAsync.isLoading && !accumulationsAsync.hasValue) {
      return PracticeSectionSkeleton(
        height: PracticeSpaceAccumulatorCard.railImageHeight + 110,
        axis: Axis.horizontal,
        itemCount: 2,
        itemWidth: 300,
        cardBorderRadius: 12,
      );
    }

    final accumulations =
        accumulationsAsync.valueOrNull?.getOrElse((_) => const []) ??
        const <GroupPractice>[];
    if (accumulations.isEmpty) return const SizedBox.shrink();

    return PracticeSectionContainer(
      title: l10n.accumulations,
      isSubsection: isSubsection,
      seeAllLabel: l10n.see_all,
      onSeeAll:
          () => openSpaceAccumulationsSeeAll(context, SpaceFilter.otherSpaces),
      child: PracticeSpaceAccumulatorRail(practices: accumulations),
    );
  }
}
