import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/home/domain/entities/series.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_explore_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_spaces_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_plan_card.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_container.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_skeleton.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_space_cards.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_spaces_section.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/space_filter_pills.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Plans to discover: the catalog's, then plans from spaces the user has
/// not joined, in one rail.
class PracticePlansSection extends ConsumerWidget {
  const PracticePlansSection({super.key, this.isSubsection = false});

  /// True under the "Discover more" heading.
  final bool isSubsection;

  static const _previewCount = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final seriesAsync = ref.watch(practiceExploreSeriesProvider);
    final spacePlans =
        ref
            .watch(
              practiceSpacePracticesProvider((
                row: PracticeSpaceRow.plans,
                joined: false,
              )),
            )
            .valueOrNull
            ?.getOrElse((_) => const []) ??
        const [];

    if (seriesAsync.isLoading && !seriesAsync.hasValue) {
      return const PracticeSectionSkeleton(
        height: 240,
        axis: Axis.horizontal,
        itemCount: 2,
        itemWidth: 300,
        cardBorderRadius: 12,
      );
    }

    final seriesList =
        seriesAsync.valueOrNull?.getOrElse((_) => const <Series>[]) ??
        const <Series>[];
    if (seriesList.isEmpty && spacePlans.isEmpty) {
      return const SizedBox.shrink();
    }
    final preview = seriesList.take(_previewCount).toList();
    final itemCount = preview.length + spacePlans.length;

    return PracticeSectionContainer(
      title: l10n.home_shortcut_plans,
      isSubsection: isSubsection,
      // The Plans screen also lists the user's own spaces' plans.
      seeAllLabel: l10n.see_all,
      onSeeAll: () => openPlansSeeAll(context, SpaceFilter.all),
      child: SizedBox(
        height: practicePlanRailHeight(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            if (index < preview.length) {
              final series = preview[index];
              return Align(
                alignment: Alignment.topCenter,
                child: PracticePlanCard(
                  series: series,
                  onTap: () => _navigateToSeries(context, series),
                ),
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: PracticeSpacePlanCard(
                practice: spacePlans[index - preview.length],
              ),
            );
          },
        ),
      ),
    );
  }

  void _navigateToSeries(BuildContext context, Series series) {
    context.pushNamed('home-series-detail', pathParameters: {'id': series.id});
  }
}
