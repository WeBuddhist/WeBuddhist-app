import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';
import 'package:flutter_pecha/features/plans/data/models/plans_model.dart';
import 'package:flutter_pecha/features/plans/data/models/user/user_plans_model.dart';
import 'package:flutter_pecha/features/plans/domain/entities/plan.dart';
import 'package:flutter_pecha/features/plans/presentation/providers/plans_providers.dart';
import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';
import 'package:flutter_pecha/features/practice/data/utils/routine_item_display.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/practice_analytics.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_chant_list_tile.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/routine_item_card.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/routine_timer_tile.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _logger = AppLogger('RoutineSessionItemTile');

/// One item of a routine session, drawn and opened the same way on
/// My Practices and on the Practice tab's Next session card.
class RoutineSessionItemTile extends ConsumerWidget {
  const RoutineSessionItemTile({
    super.key,
    required this.item,
    required this.blockIndex,
    required this.blockTime,
  });

  final RoutineItem item;

  /// Where the session sits in the routine, for analytics.
  final int blockIndex;
  final TimeOfDay blockTime;

  Future<void> _onItemTap(BuildContext context, WidgetRef ref) async {
    switch (item.type) {
      case RoutineItemType.recitation:
        context.push(
          '/reader/${item.id}',
          extra: NavigationContext(source: NavigationSource.routine),
        );
      case RoutineItemType.plan:
        if (!await _openPlanDetails(context, ref, planId: item.id)) return;
      case RoutineItemType.series:
        if (!context.mounted) return;
        context.pushNamed(
          'home-series-detail',
          pathParameters: {'id': item.id},
        );
      case RoutineItemType.timer:
        if (!_navigateToTimer(context)) return;
      case RoutineItemType.accumulator:
        context.push(
          '/mala',
          extra: {'presetId': item.id, 'source': MalaOpenSource.routine},
        );
      case RoutineItemType.groupAccumulator:
        context.pushNamed(
          'home-group-accumulator',
          pathParameters: {'accumulatorId': item.id},
        );
      case RoutineItemType.groupRecitationCollection:
        context.pushNamed(
          'recitation-collection',
          pathParameters: {'collectionId': item.id},
          extra: {'title': item.title},
        );
      case RoutineItemType.myRecitationCollection:
        context.pushNamed(
          'my-recitation-collection',
          pathParameters: {'collectionId': item.id},
          extra: {'title': item.title},
        );
      case RoutineItemType.unknown:
        // Written by a newer app version — nothing here knows how to open it.
        return;
    }
    if (!context.mounted) return;
    _trackItemOpened(context, ref);
  }

  Future<void> _onPlanArrowTap(BuildContext context, WidgetRef ref) async {
    final planId = item.currentPlanId;
    if (planId == null || planId.isEmpty) return;
    if (await _openPlanDetails(context, ref, planId: planId)) {
      if (!context.mounted) return;
      _trackItemOpened(context, ref);
    }
  }

  /// Fired once the item's screen has been pushed.
  void _trackItemOpened(BuildContext context, WidgetRef ref) {
    ref
        .read(practiceAnalyticsProvider)
        .routineItemOpened(
          item: item,
          blockIndex: blockIndex,
          blockTime: blockTime,
        );
  }

  /// Returns false when the item has no duration and nothing was opened.
  bool _navigateToTimer(BuildContext context) {
    final durationMs = item.durationMs;
    if (durationMs == null || durationMs <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.notFound)));
      return false;
    }

    final name = routineItemDisplayTitle(item, context.l10n);
    context.push(
      '/home/timers/active',
      extra: routineTimerFor(item, name: name, durationMs: durationMs),
    );
    return true;
  }

  /// Opens plan details for [planId]. For PLAN sessions that id is
  /// `source_id` from GET /users/me/routine. Does not search My Plans.
  Future<bool> _openPlanDetails(
    BuildContext context,
    WidgetRef ref, {
    required String planId,
  }) async {
    final catalogEither = await ref.read(planByIdFutureProvider(planId).future);
    final catalogPlan = catalogEither.fold((_) => null, (plan) => plan);
    if (catalogPlan == null) {
      _logger.warning('[ENROLL-NAV] plan $planId not found');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.notFound)));
      }
      return false;
    }
    if (!context.mounted) return false;
    final userPlan = _userPlanFromCatalogPlan(catalogPlan, item);
    final startDate = item.startDate ?? item.enrolledAt ?? userPlan.startedAt;
    final daysSinceEnrollment =
        DateTime.now().difference(DateUtils.dateOnly(startDate)).inDays;
    final selectedDay = (daysSinceEnrollment + 1).clamp(1, userPlan.totalDays);
    _logger.info(
      '[ENROLL-NAV] open plan ${userPlan.id} selectedDay=$selectedDay/${userPlan.totalDays}',
    );
    context.push(
      '/practice/details',
      extra: {
        'plan': userPlan,
        'selectedDay': selectedDay,
        'startDate': startDate,
        if (item.type == RoutineItemType.series) 'seriesId': item.id,
      },
    );
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.type == RoutineItemType.recitation) {
      return PracticeChantListTile(
        recitation: recitationModelFromRoutineItem(item),
        includeOuterPadding: false,
        onTap: () => _onItemTap(context, ref),
      );
    }

    if (item.type == RoutineItemType.timer) {
      return RoutineTimerTile(
        item: item,
        onTap: () => _onItemTap(context, ref),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollection =
        item.type == RoutineItemType.groupRecitationCollection ||
        item.type == RoutineItemType.myRecitationCollection;
    final itemCount = item.itemCount;

    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: RoutineItemCard(
          title: routineItemDisplayTitle(item, context.l10n),
          coverImage: item.coverImage,
          type: item.type,
          planTitle:
              isCollection && itemCount != null && itemCount > 0
                  ? context.l10n.my_recitation_collection_chant_count(itemCount)
                  : item.currentPlanTitle,
          imageSize: 56,
          onTap: () => _onItemTap(context, ref),
          onPlanTap:
              item.type == RoutineItemType.series && item.currentPlanId != null
                  ? () => _onPlanArrowTap(context, ref)
                  : null,
        ),
      ),
    );
  }
}

/// The timer a routine timer item plays. A linked item plays its saved timer
/// (sound, bells, and the id stops are reported against). A bare duration has
/// no saved timer, so it gets an empty id and its stop is not reported.
PresetTimer routineTimerFor(
  RoutineItem? item, {
  required String name,
  required int durationMs,
}) {
  final linked = item?.timer;
  if (linked != null && linked.id.isNotEmpty) {
    final timer = linked.toEntity();
    return PresetTimer(
      id: timer.id,
      name: name,
      durationMs: durationMs,
      userId: timer.userId,
      groupId: timer.groupId,
      type: timer.type,
      description: timer.description,
      ambientSoundId: timer.ambientSoundId,
      bellAtStart: timer.bellAtStart,
      bellAtEnd: timer.bellAtEnd,
      parentPresetId: timer.parentPresetId,
      createdAt: timer.createdAt,
      updatedAt: timer.updatedAt,
    );
  }
  return PresetTimer(id: '', name: name, durationMs: durationMs);
}

UserPlansModel _userPlanFromCatalogPlan(Plan plan, RoutineItem item) {
  return UserPlansModel(
    id: plan.id,
    title: plan.title,
    description: plan.description,
    language: plan.language,
    difficultyLevel: plan.difficulty.name,
    image:
        plan.coverImage != null
            ? ImageModel.fromResponsiveImage(plan.coverImage!)
            : null,
    startedAt:
        item.enrolledAt ?? item.startDate ?? plan.startDate ?? DateTime.now(),
    totalDays: plan.totalDays,
    tags: null,
    startDate: item.startDate ?? plan.startDate,
  );
}
