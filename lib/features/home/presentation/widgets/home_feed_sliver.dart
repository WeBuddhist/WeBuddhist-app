import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/utils/connect_analytics.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_feed_item_view.dart';
import 'package:flutter_pecha/features/home/presentation/home_screen_constants.dart';
import 'package:flutter_pecha/features/home/presentation/providers/home_feed_provider.dart';
import 'package:flutter_pecha/features/home/presentation/providers/home_poems_preview_provider.dart';
import 'package:flutter_pecha/features/home/presentation/utils/home_feed_rows.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/group_events_section_skeleton.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/home_share_prompt.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/poems_section.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home's "From the community": posts and events that page in as Home
/// scrolls, with poems and the share block placed between them.
class HomeFeedSliver extends ConsumerWidget {
  const HomeFeedSliver({super.key});

  /// How close to the end of Home the next page is asked for.
  static const double loadMoreExtent = 800;

  /// For the scroll view's `NotificationListener`: asks for the next page
  /// once Home is scrolled near its end. Never consumes the notification.
  static bool onScroll(WidgetRef ref, ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < loadMoreExtent) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
    return false;
  }

  /// For a sliver's build: scrolling asks for pages, but a page that adds
  /// little (or nothing, after filtering) can leave Home's end in reach with
  /// no scroll to come. After the frame, asks for the next page if so.
  static void continuePaging(
    BuildContext context,
    WidgetRef ref,
    HomeFeedState state,
  ) {
    if (!state.canLoadMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final position = Scrollable.maybeOf(context)?.position;
      if (position != null &&
          position.hasContentDimensions &&
          position.extentAfter < loadMoreExtent) {
        ref.read(homeFeedProvider.notifier).loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeFeedProvider);
    final signedIn = ref.watch(
      authProvider.select((auth) => auth.isLoggedIn && !auth.isGuest),
    );
    ref.watch(
      connectPostViewTrackerProvider((
        surface: ConnectPostSurface.homePreview,
        visitId: null,
      )),
    );
    // The poems row is built lazily; without a listener here its provider
    // would be dropped, and poems fetched again, each time it scrolls off.
    ref.listen(homePoemsPreviewProvider, (_, _) {});

    continuePaging(context, ref, state);

    if (state.items.isEmpty && !state.feedEnded) {
      return const SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_FeedTitle(), GroupEventsSectionSkeleton()],
        ),
      );
    }

    final rows = buildHomeFeedRows(state.items, feedEnded: state.feedEnded);
    final hasTitle = state.items.isNotEmpty;
    final footer = _footer(context, ref, state);
    // Right after the last card, ahead of the poems and share that close a
    // short feed; first when there are no cards.
    final footerAt = rows.lastIndexWhere((row) => row is HomeFeedItemRow) + 1;
    final count = (hasTitle ? 1 : 0) + rows.length + (footer == null ? 0 : 1);

    return SliverList.builder(
      itemCount: count,
      itemBuilder: (context, index) {
        if (hasTitle && index == 0) return const _FeedTitle();
        var rowIndex = index - (hasTitle ? 1 : 0);
        if (footer != null) {
          if (rowIndex == footerAt) return footer;
          if (rowIndex > footerAt) rowIndex--;
        }
        final row = rows[rowIndex];
        final previous = rowIndex > 0 ? rows[rowIndex - 1] : null;
        return switch (row) {
          HomeFeedItemRow(:final item, :final position) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (previous is HomeFeedItemRow) const _CardDivider(),
              ConnectFeedItemView(
                item: item,
                includeUnfollowed: !signedIn || !item.isJoined,
                placement: ConnectPostPlacement(
                  surface: ConnectPostSurface.homePreview,
                  position: position,
                ),
              ),
            ],
          ),
          HomeFeedPoemsRow() => const Padding(
            padding: EdgeInsets.only(top: HomeScreenConstants.cardSpacing),
            child: PoemsSection(),
          ),
          HomeFeedShareRow() => const HomeSharePrompt(),
        };
      },
    );
  }

  /// Spinner while a page loads; after any failed read (page one included,
  /// stored cards or not) a message with Retry.
  Widget? _footer(BuildContext context, WidgetRef ref, HomeFeedState state) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null && !state.isLoading) {
      return HomeFeedErrorRow(
        onRetry: () => ref.read(homeFeedProvider.notifier).retry(),
      );
    }
    return null;
  }
}

/// "Something went wrong" with Retry, where the feed stopped.
class HomeFeedErrorRow extends StatelessWidget {
  const HomeFeedErrorRow({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontSize = getLocalizedFontSize(AppTextSize.body);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Text(
            context.l10n.something_went_wrong,
            textAlign: TextAlign.center,
            strutStyle: context.tibetanStrutStyle(fontSize),
            style: TextStyle(
              fontSize: fontSize,
              color: isDark ? AppColors.grey400 : AppColors.grey600,
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}

class _FeedTitle extends StatelessWidget {
  const _FeedTitle();

  @override
  Widget build(BuildContext context) {
    final isTibetan = context.isTibetanLocale;
    final fontSize = getLocalizedFontSize(AppTextSize.bodyLarge);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, isTibetan ? 16 : 12),
      child: Text(
        context.l10n.home_community_feed,
        strutStyle: context.tibetanStrutStyle(fontSize, compact: true),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: isTibetan ? AppFontConfig.tibetanCompactLineHeight : 1.2,
          leadingDistribution:
              isTibetan ? AppFontConfig.tibetanLeadingDistribution : null,
        ),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppColors.cardBorderDark : AppColors.grey100,
    );
  }
}
