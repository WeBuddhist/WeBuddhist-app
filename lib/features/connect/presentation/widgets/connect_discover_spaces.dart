import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/error_state_widget.dart';
import 'package:flutter_pecha/features/connect/domain/entities/space_sort.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/group_search_result_card.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_profile_tab_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Looking for" with the sort menu at the end, above the spaces list.
class ConnectLookingForHeader extends StatelessWidget {
  const ConnectLookingForHeader({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 4),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.connect_looking_for,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          const ConnectSpaceSortMenu(),
        ],
      ),
    );
  }
}

/// Outlined pill showing the current order; opens Popular / Newly added /
/// Most active, with a check on the current one.
class ConnectSpaceSortMenu extends ConsumerStatefulWidget {
  const ConnectSpaceSortMenu({super.key});

  @override
  ConsumerState<ConnectSpaceSortMenu> createState() =>
      _ConnectSpaceSortMenuState();
}

class _ConnectSpaceSortMenuState extends ConsumerState<ConnectSpaceSortMenu> {
  bool _open = false;

  void _setOpen(bool open) {
    if (mounted && open != _open) setState(() => _open = open);
  }

  @override
  Widget build(BuildContext context) {
    final sort = ref.watch(discoverSpaceSortProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor =
        _open
            ? textColor
            : (isDark ? AppColors.cardBorderDark : AppColors.grey300);

    return PopupMenuButton<SpaceSort>(
      tooltip: context.l10n.connect_sort_spaces,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceWhite,
      constraints: const BoxConstraints(minWidth: 168),
      menuPadding: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.cardBorderDark : AppColors.grey300,
        ),
      ),
      onOpened: () => _setOpen(true),
      onCanceled: () => _setOpen(false),
      onSelected: (value) {
        _setOpen(false);
        ref.read(discoverSpaceSortProvider.notifier).state = value;
      },
      itemBuilder:
          (context) => [
            for (final option in SpaceSort.values)
              _item(context, option, selected: option == sort),
          ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
        decoration: ShapeDecoration(
          shape: StadiumBorder(side: BorderSide(color: borderColor)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sort.label(context),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _open ? AppAssets.caretUp : AppAssets.caretDown,
              size: 14,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<SpaceSort> _item(
    BuildContext context,
    SpaceSort option, {
    required bool selected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return PopupMenuItem<SpaceSort>(
      value: option,
      height: 40,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                selected
                    ? (isDark
                        ? AppColors.surfaceVariantDark
                        : AppColors.grey100)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label(context),
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 12),
                  Icon(AppAssets.check, size: 16, color: textColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension SpaceSortLabel on SpaceSort {
  String label(BuildContext context) => switch (this) {
    SpaceSort.popular => context.l10n.connect_sort_popular,
    SpaceSort.newlyAdded => context.l10n.connect_sort_newly_added,
    SpaceSort.mostActive => context.l10n.connect_sort_most_active,
  };
}

/// The "Looking for" spaces as slivers: a skeleton on first load, the error
/// or empty message, or the rows with a spinner while the next page loads.
List<Widget> buildDiscoverSpaceSlivers(
  BuildContext context,
  DiscoverGroupsState state,
  DiscoverGroupsNotifier notifier,
) {
  final groups = state.groups;
  if (groups.isEmpty) {
    if (state.isLoading || !state.hasLoaded) {
      return const [
        SliverToBoxAdapter(
          child: GroupProfileTabSkeleton.box(
            variant: GroupProfileTabSkeletonVariant.member,
          ),
        ),
      ];
    }

    final Widget child;
    if (state.error != null) {
      child = ErrorStateWidget(error: state.error!, onRetry: notifier.retry);
    } else {
      child = Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.l10n.no_groups_found,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return [SliverToBoxAdapter(child: child)];
  }

  return [
    SliverList.builder(
      itemCount: groups.length,
      itemBuilder:
          (context, index) => GroupSearchResultCard(group: groups[index]),
    ),
    if (state.isLoadingMore)
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
  ];
}
