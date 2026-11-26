import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/l10n/intl_format_locale.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/core/widgets/responsive_cover_image.dart';
import 'package:flutter_pecha/features/connect/presentation/utils/connect_ended_utils.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_accumulator.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/series_plan_card_widgets.dart';
import 'package:flutter_pecha/features/plans/data/utils/plan_date_format.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _fallbackCover = 'assets/images/tag_cover/cover_image.jpg';
const double _cardRadius = 12;

/// Opens a space plan or series the way its Connect card does: an enrolled
/// series opens as is, an unjoined one carries its space so the user can
/// practice with it, and a plan opens its preview.
void openSpacePlanPractice(BuildContext context, GroupPractice practice) {
  final series = practice.series;
  if (practice.type == GroupPracticeType.series && series != null) {
    final isEnrolled = practice.isJoined || series.isGroupEnrolled == true;
    context.push(
      '/home/series/${series.id}',
      extra:
          isEnrolled
              ? null
              : {
                if (practice.groupId != null) 'groupId': practice.groupId,
                'groupType': GroupType.community,
                'isGroupEnrolled': false,
              },
    );
    return;
  }
  final plan = practice.plan;
  if (plan == null) return;
  context.push(
    '/practice/plans/preview',
    extra: {
      'plan': plan.toPlan(),
      if (plan.seriesId != null) 'seriesId': plan.seriesId,
    },
  );
}

/// A space plan or series in a Practice tab rail, laid out like the
/// catalog's plan card, with the space it belongs to across the image.
class PracticeSpacePlanCard extends StatelessWidget {
  const PracticeSpacePlanCard({
    super.key,
    required this.practice,
    this.width = 300,
  });

  final GroupPractice practice;
  final double width;

  static const double imageHeight = 150;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final series = practice.series;
    final plan = practice.plan;
    final title = series?.title ?? plan?.title ?? '';
    final dateRange =
        series != null
            ? PlanDateFormat.formatRangeOrNull(series.startDate, series.endDate)
            : (plan?.startDate != null
                ? PlanDateFormat.formatDate(plan!.startDate!)
                : null);
    final enrolledCount = series?.enrolledCount ?? 0;
    final groupName = practice.groupName?.trim() ?? '';
    final metaColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => openSpacePlanPractice(context, practice),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius),
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_cardRadius),
              ),
              child: SizedBox(
                height: imageHeight,
                width: width,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    series != null
                        ? ResponsiveCoverImage(
                          image: series.image,
                          fallbackAsset: _fallbackCover,
                          fit: BoxFit.cover,
                        )
                        : CachedNetworkImageWidget(
                          imageUrl: plan?.imageUrl,
                          fallbackAsset: _fallbackCover,
                          width: width,
                          height: imageHeight,
                        ),
                    if (groupName.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _SpaceBar(
                          label: context.l10n.series_practicing_with_group(
                            groupName,
                          ),
                          avatarUrl: practice.groupAvatarUrl,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            if (dateRange != null || enrolledCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateRange ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: metaColor,
                        ),
                      ),
                    ),
                    if (enrolledCount > 0)
                      SeriesPlanEnrolledCount(
                        count: enrolledCount,
                        fontSize: 12,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A space plan or series as a row on the Plans screen, beside the
/// catalog's `PracticePlanListTile`: thumbnail, the space, the title, then
/// the dates and how many are practicing.
class PracticeSpacePlanListTile extends StatelessWidget {
  const PracticeSpacePlanListTile({super.key, required this.practice});

  final GroupPractice practice;

  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;
    final series = practice.series;
    final plan = practice.plan;
    final title = series?.title ?? plan?.title ?? '';
    final dateRange =
        series != null
            ? PlanDateFormat.formatRangeOrNull(series.startDate, series.endDate)
            : (plan?.startDate != null
                ? PlanDateFormat.formatDate(plan!.startDate!)
                : null);
    final enrolledCount = series?.enrolledCount ?? 0;
    final groupName = practice.groupName?.trim() ?? '';

    return Material(
      color: isDark ? AppColors.cardBackgroundDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => openSpacePlanPractice(context, practice),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: _thumbSize,
                  child:
                      series != null
                          ? ResponsiveCoverImage(
                            image: series.image,
                            fallbackAsset: _fallbackCover,
                            fit: BoxFit.cover,
                            width: _thumbSize,
                            height: _thumbSize,
                          )
                          : CachedNetworkImageWidget(
                            imageUrl: plan?.imageUrl,
                            fallbackAsset: _fallbackCover,
                            width: _thumbSize,
                            height: _thumbSize,
                          ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (groupName.isNotEmpty) ...[
                      Row(
                        children: [
                          _Avatar(url: practice.groupAvatarUrl, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: secondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (dateRange != null || enrolledCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateRange ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: secondary),
                            ),
                          ),
                          if (enrolledCount > 0)
                            SeriesPlanEnrolledCount(
                              count: enrolledCount,
                              fontSize: 12,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A space accumulation in a Practice tab rail: cover with its dates, the
/// space, the title, and the progress toward the target.
class PracticeSpaceAccumulatorCard extends StatelessWidget {
  const PracticeSpaceAccumulatorCard({
    super.key,
    required this.practice,
    required this.accumulator,
    this.width = 300,
    this.imageHeight = railImageHeight,
  });

  final GroupPractice practice;
  final GroupAccumulator accumulator;
  final double width;
  final double imageHeight;

  /// Cover height in a horizontal rail.
  static const double railImageHeight = 120;

  void _open(BuildContext context) {
    final groupName = practice.groupName?.trim();
    context.push(
      '/home/group-accumulator/${accumulator.id}',
      extra: {
        'groupTitle':
            groupName != null && groupName.isNotEmpty ? groupName : null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;
    final hasEnded = isPastEndDate(accumulator.endDate, DateTime.now());
    final dateBadge =
        hasEnded
            ? context.l10n.connect_ended_on(
              PlanDateFormat.formatDate(accumulator.endDate!),
            )
            : PlanDateFormat.formatRangeOrNull(
              accumulator.startDate,
              accumulator.endDate,
            );
    final numberFormat = NumberFormat.decimalPattern(
      intlFormatLocaleOf(context),
    );
    final target = accumulator.targetCount;
    final progress =
        target > 0 ? (accumulator.totalCount / target).clamp(0.0, 1.0) : 0.0;
    final groupName = practice.groupName?.trim() ?? '';

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius),
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_cardRadius),
              ),
              child: SizedBox(
                height: imageHeight,
                width: width,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ResponsiveCoverImage(
                      image: accumulator.image,
                      fallbackAsset: _fallbackCover,
                      fit: BoxFit.cover,
                    ),
                    if (dateBadge != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _Badge(label: dateBadge),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (groupName.isNotEmpty) ...[
                    Row(
                      children: [
                        _Avatar(url: practice.groupAvatarUrl, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: secondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    accumulator.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (target > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor:
                            isDark ? AppColors.grey800 : AppColors.grey100,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accentGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${numberFormat.format(accumulator.totalCount)} / '
                            '${numberFormat.format(target)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: secondary),
                          ),
                        ),
                        Text(
                          '${(progress * 100).floor()}%',
                          style: TextStyle(fontSize: 11, color: secondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark strip across the bottom of a cover naming the space.
class _SpaceBar extends StatelessWidget {
  const _SpaceBar({required this.label, this.avatarUrl});

  final String label;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: Colors.black.withValues(alpha: 0.55),
      child: Row(
        children: [
          _Avatar(url: avatarUrl, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child:
            hasUrl
                ? CachedNetworkImageWidget(
                  imageUrl: url,
                  width: size,
                  height: size,
                )
                : ColoredBox(
                  color: isDark ? AppColors.grey800 : AppColors.grey300,
                ),
      ),
    );
  }
}
