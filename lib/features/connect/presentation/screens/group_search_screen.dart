import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/error_state_widget.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/group_search_provider.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_discover_spaces.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/group_search_result_card.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_profile_tab_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupSearchScreen extends ConsumerStatefulWidget {
  const GroupSearchScreen({super.key});

  @override
  ConsumerState<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends ConsumerState<GroupSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onSearchTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.removeListener(_onSearchTextChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The bottom of the page is the end of "Looking for": page that list.
  /// Search results page on their own, from their last row.
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    ref.read(discoverGroupsProvider.notifier).loadMore();
  }

  /// Called as the last result is built, i.e. once it scrolls within the
  /// viewport's cache extent. A failed page waits for the retry row, so a
  /// rebuild doesn't refetch it in a loop.
  void _onLastResultBuilt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final search = ref.read(groupSearchProvider);
      if (search.error != null) return;
      ref.read(groupSearchProvider.notifier).loadMore();
    });
  }

  void _onQueryChanged(String query) {
    ref.read(groupSearchProvider.notifier).search(query);
  }

  void _onClear() {
    _searchController.clear();
    ref.read(groupSearchProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchState = ref.watch(groupSearchProvider);
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.grey300;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(groupSearchProvider.notifier).clear();
                      Navigator.of(context).pop();
                    },
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(AppAssets.arrowLeft),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: context.l10n.connect_find_your_space,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          AppAssets.exploreUnselected,
                          size: 20,
                          color: subtitleColor,
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  onPressed: _onClear,
                                  tooltip:
                                      MaterialLocalizations.of(
                                        context,
                                      ).deleteButtonTooltip,
                                  icon: Icon(
                                    AppAssets.x,
                                    size: 18,
                                    color: subtitleColor,
                                  ),
                                )
                                : null,
                        filled: true,
                        fillColor:
                            isDark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceWhite,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, searchState)),
          ],
        ),
      ),
    );
  }

  /// Search results (when there is a query) above the "Looking for" list,
  /// in one scroll: screens 3–6 of the design.
  Widget _buildBody(BuildContext context, GroupSearchState searchState) {
    final discoverState = ref.watch(discoverGroupsProvider);
    final discoverNotifier = ref.read(discoverGroupsProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(discoverGroupsProvider.notifier).ensureLoaded();
    });

    final hasQuery = searchState.query.trim().isNotEmpty;

    return CustomScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (hasQuery) ..._buildResults(context, searchState),
        SliverToBoxAdapter(
          child: ConnectLookingForHeader(
            padding: EdgeInsets.fromLTRB(16, hasQuery ? 20 : 12, 16, 4),
          ),
        ),
        ...buildDiscoverSpaceSlivers(context, discoverState, discoverNotifier),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<Widget> _buildResults(BuildContext context, GroupSearchState state) {
    if (state.isLoading && state.results.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: GroupProfileTabSkeleton.box(
            variant: GroupProfileTabSkeletonVariant.member,
          ),
        ),
      ];
    }

    if (state.error != null && state.results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorStateWidget(
            error: state.error!,
            onRetry: () => ref.read(groupSearchProvider.notifier).retry(),
          ),
        ),
      ];
    }

    if (state.results.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              context.l10n.connect_no_spaces_match(state.query.trim()),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color:
                    isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverList.builder(
        itemCount: state.results.length,
        itemBuilder: (context, index) {
          if (index == state.results.length - 1 && state.hasMore) {
            _onLastResultBuilt();
          }
          return GroupSearchResultCard(group: state.results[index]);
        },
      ),
      if (state.isLoadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        )
      else if (state.error != null)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton(
              onPressed: () => ref.read(groupSearchProvider.notifier).retry(),
              child: Text(context.l10n.retry),
            ),
          ),
        ),
    ];
  }
}
