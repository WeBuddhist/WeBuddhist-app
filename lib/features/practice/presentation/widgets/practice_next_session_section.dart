import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/next_routine_session.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_container.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/routine_session_item_tile.dart';
import 'package:go_router/go_router.dart';

/// "Next session" on the Practice tab: the routine session that starts
/// next, its first item, and the rest behind an expand toggle. See all
/// opens My Practices.
///
/// Rechecks the clock every minute, so the card moves on to the following
/// session once this one has started.
class PracticeNextSessionSection extends StatefulWidget {
  const PracticeNextSessionSection({super.key, required this.routine});

  final RoutineData routine;

  @override
  State<PracticeNextSessionSection> createState() =>
      _PracticeNextSessionSectionState();
}

class _PracticeNextSessionSectionState
    extends State<PracticeNextSessionSection> {
  Timer? _ticker;
  bool _expanded = false;
  String? _shownBlockId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = nextRoutineSession(widget.routine, DateTime.now());
      if (next?.block.id != _shownBlockId) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = nextRoutineSession(widget.routine, DateTime.now());
    if (next == null) return const SizedBox.shrink();
    final block = next.block;
    // A different session folds back to its first item.
    if (block.id != _shownBlockId) {
      _shownBlockId = block.id;
      _expanded = false;
    }

    final l10n = context.l10n;
    return PracticeSectionContainer(
      title: l10n.practice_next_session,
      seeAllLabel: l10n.see_all,
      onSeeAll: () => context.pushNamed('my-practices'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _SessionCard(
          block: block,
          blockIndex: next.index,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.block,
    required this.blockIndex,
    required this.expanded,
    required this.onToggle,
  });

  final RoutineBlock block;
  final int blockIndex;
  final bool expanded;
  final VoidCallback onToggle;

  Widget _tile(RoutineItem item) {
    return RoutineSessionItemTile(
      item: item,
      blockIndex: blockIndex,
      blockTime: block.time,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary =
        isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;
    final items = block.items;
    final moreCount = items.length - 1;
    final canExpand = moreCount > 0;
    final title = block.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: canExpand ? onToggle : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasTitle ? title : block.formattedTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: primary,
                        ),
                      ),
                      if (hasTitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          block.formattedTime,
                          style: TextStyle(fontSize: 13, color: secondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canExpand)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      expanded ? AppAssets.caretUp : AppAssets.caretDown,
                      size: 18,
                      color: secondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        _tile(items.first),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child:
              expanded
                  ? Column(
                    children: [
                      for (final item in items.skip(1)) ...[
                        const SizedBox(height: 8),
                        _tile(item),
                      ],
                    ],
                  )
                  : canExpand
                  ? Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: onToggle,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          context.l10n.practice_more_in_session(moreCount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondary,
                          ),
                        ),
                      ),
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
