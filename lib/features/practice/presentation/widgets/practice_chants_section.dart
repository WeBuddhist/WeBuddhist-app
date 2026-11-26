import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_explore_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_spaces_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/all_recitations_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/chant_books_see_all_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/recitation_reader_navigation.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_chant_list_tile.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_container.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_skeleton.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_spaces_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chants to discover: chant books from spaces the user has not joined in
/// a rail, then a preview of the catalog's chants.
class PracticeChantsSection extends ConsumerWidget {
  const PracticeChantsSection({super.key, this.isSubsection = false});

  /// True under the "Discover more" heading.
  final bool isSubsection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recitationsAsync = ref.watch(practiceExploreRecitationsProvider);
    final spaceBooks = ref.watch(practiceSpaceChantBooksProvider(false));

    if (recitationsAsync.isLoading && !recitationsAsync.hasValue) {
      return const PracticeSectionSkeleton(
        height: 176,
        itemCount: 2,
        itemSpacing: 8,
        cardBorderRadius: 12,
        style: PracticeSectionSkeletonStyle.chantTile,
      );
    }

    final page = recitationsAsync.valueOrNull?.fold((_) => null, (p) => p);
    final recitations = page?.recitations ?? const [];
    if (recitations.isEmpty && spaceBooks.isEmpty) {
      return const SizedBox.shrink();
    }
    // See all opens the chant books screen on "Other spaces", the same
    // screen "From your spaces" opens on "Your spaces". With no such books
    // but more catalog chants than the preview, it opens the full chant
    // list instead, so those chants are still reachable.
    final VoidCallback? onSeeAll =
        spaceBooks.isNotEmpty
            ? () => openChantBooksSeeAll(context, ChantBooksSeeAll.otherSpaces)
            : (page != null && page.total > recitations.length)
            ? () => _showAllRecitations(context)
            : null;

    return PracticeSectionContainer(
      title: l10n.home_chants,
      isSubsection: isSubsection,
      seeAllLabel: onSeeAll != null ? l10n.see_all : null,
      onSeeAll: onSeeAll,
      child: Column(
        children: [
          if (spaceBooks.isNotEmpty) ...[
            PracticeChantBookRail(
              books: spaceBooks.take(practiceSpacePreviewLimit).toList(),
            ),
            if (recitations.isNotEmpty) const SizedBox(height: 12),
          ],
          for (final r in recitations)
            PracticeChantListTile(
              recitation: r,
              onTap: () => openRecitationReader(context, r),
            ),
        ],
      ),
    );
  }

  void _showAllRecitations(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'all-recitations'),
        builder: (_) => const AllRecitationsScreen(),
      ),
    );
  }
}
