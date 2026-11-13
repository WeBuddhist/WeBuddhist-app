import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/core/utils/network_image_utils.dart';
import 'package:flutter_pecha/core/widgets/responsive_cover_image.dart';
import 'package:flutter_pecha/core/widgets/skeletons/skeletons.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/practice/data/models/session_selection.dart';
import 'package:flutter_pecha/features/practice/domain/entities/practice_item.dart';
import 'package:flutter_pecha/features/practice/domain/entities/practice_items_tab.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_items_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_chant_list_tile.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_pecha/features/recitation/presentation/widgets/recitation_list_skeleton.dart';
import 'package:flutter_pecha/features/timer/domain/entities/preset_timer.dart';
import 'package:flutter_pecha/features/timer/presentation/providers/timers_providers.dart';
import 'package:flutter_pecha/shared/domain/value_objects/responsive_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pecha/features/plans/data/utils/plan_date_format.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/cache/app_image_cache_manager.dart';
import 'package:skeletonizer/skeletonizer.dart';

final _logger = AppLogger('SelectSessionScreen');

/// Session picker with four tabs: Plans · Chants · Malas · Timers.
/// Returns a [SessionSelection] subtype that [EditRoutineScreen] dispatches on.
class SelectSessionScreen extends ConsumerStatefulWidget {
  const SelectSessionScreen({super.key});

  @override
  ConsumerState<SelectSessionScreen> createState() =>
      _SelectSessionScreenState();
}

class _SelectSessionScreenState extends ConsumerState<SelectSessionScreen>
    with SingleTickerProviderStateMixin {
  static const PracticeItemsTab _practiceTab = PracticeItemsTab.all;

  late TabController _tabController;
  final ScrollController _plansScrollController = ScrollController();
  final ScrollController _chantsScrollController = ScrollController();

  final String? _enrollingItemId = null;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  final Map<int, String> _queriesByTab = {
    0: '', // Plans/Series
    1: '', // Chants
    2: '', // Malas
    3: '', // Timers
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _plansScrollController.addListener(_onPlansScroll);
    _chantsScrollController.addListener(_onChantsScroll);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _plansScrollController.removeListener(_onPlansScroll);
    _plansScrollController.dispose();
    _chantsScrollController.removeListener(_onChantsScroll);
    _chantsScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();

    // Clear shared search providers when the picker closes so Explore search
    // does not open with a leftover query.
    final languageCode = ref.read(contentLanguageProvider);
    ref.read(practiceRecitationSearchProvider(languageCode).notifier).clear();
    ref.read(accumulationSearchProvider.notifier).clear();

    super.dispose();
  }

  void _onPlansScroll() {
    if (_plansScrollController.position.pixels >=
        _plansScrollController.position.maxScrollExtent - 200) {
      ref
          .read(practiceItemsPaginatedProvider(_practiceTab).notifier)
          .loadMore();
    }
  }

  void _onChantsScroll() {
    if (_chantsScrollController.position.pixels >=
        _chantsScrollController.position.maxScrollExtent - 200) {
      final languageCode = ref.read(contentLanguageProvider);
      ref
          .read(practiceRecitationsPaginatedProvider(languageCode).notifier)
          .loadMore();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (!_isSearching) return;

    final activeTab = _tabController.index;
    final tabQuery = _queriesByTab[activeTab] ?? '';

    _searchController.value = _searchController.value.copyWith(
      text: tabQuery,
      selection: TextSelection.collapsed(offset: tabQuery.length),
    );
  }

  void _onSearchChanged(String query) {
    final activeTab = _tabController.index;
    _queriesByTab[activeTab] = query;

    final languageCode = ref.read(contentLanguageProvider);
    if (activeTab == 1) {
      ref.read(practiceRecitationSearchProvider(languageCode).notifier).search(query);
    } else if (activeTab == 2) {
      ref.read(accumulationSearchProvider.notifier).search(query);
    }

    setState(() {});
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    final activeTab = _tabController.index;
    _queriesByTab[activeTab] = '';
    _searchController.clear();

    final languageCode = ref.read(contentLanguageProvider);
    if (activeTab == 1) {
      ref.read(practiceRecitationSearchProvider(languageCode).notifier).clear();
    } else if (activeTab == 2) {
      ref.read(accumulationSearchProvider.notifier).clear();
    }

    setState(() => _isSearching = false);
  }

  void _onPracticeItemSelected(PracticeItem item) {
    if (_enrollingItemId != null) return;
    final selection = switch (item) {
      PracticePlanItem(:final plan) => PlanSessionSelection(plan),
      PracticeSeriesItem(:final series) => SeriesSessionSelection(series),
    };
    Navigator.of(context).pop<SessionSelection>(selection);
  }

  void _onRecitationSelected(RecitationModel recitation) {
    if (_enrollingItemId != null) return;
    Navigator.of(
      context,
    ).pop<SessionSelection>(RecitationSessionSelection(recitation));
  }

  void _onMantraSelected(Mantra mantra) {
    Navigator.of(context).pop<SessionSelection>(MantraSessionSelection(mantra));
  }

  void _onTimerSelected(PresetTimer timer) {
    Navigator.of(context).pop<SessionSelection>(TimerSessionSelection(timer));
  }

  String _searchHint(AppLocalizations localizations) {
    return switch (_tabController.index) {
      0 => localizations.search_plans,
      1 => localizations.recitations_search,
      2 => localizations.accumulations_search,
      _ => localizations.text_search_hint,
    };
  }

  Widget _buildSearchHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.grey300;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _closeSearch,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: _searchHint(localizations),
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: subtitleColor,
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: subtitleColor,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            _searchFocusNode.requestFocus();
                          },
                          icon: Icon(
                            Icons.clear,
                            size: 20,
                            color: subtitleColor,
                          ),
                        )
                        : null,
                filled: true,
                fillColor:
                    isDark ? AppColors.surfaceDark : AppColors.surfaceWhite,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
    );
  }

  Widget _buildSearchResults() {
    final query = _queriesByTab[_tabController.index] ?? '';

    // Plans search waits on a dedicated backend; keep the field but do not query.
    if (_tabController.index == 0) {
      return _SessionTabMessage(
        message: AppLocalizations.of(context)!.comingSoonHeadline,
      );
    }

    if (query.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return switch (_tabController.index) {
      1 => _ChantsTab(
        scrollController: _chantsScrollController,
        enrollingItemId: _enrollingItemId,
        onRecitationSelected: _onRecitationSelected,
        searchQuery: query,
      ),
      2 => _MalasTab(
        onMantraSelected: _onMantraSelected,
        searchQuery: query,
      ),
      _ => _TimersTab(
        onTimerSelected: _onTimerSelected,
        searchQuery: query,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context)!;

    if (_isSearching) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchHeader(context, isDark),
              Expanded(child: _buildSearchResults()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppAssets.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          localizations.routine_add_session,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: _openSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: localizations.home_shortcut_plans),
            Tab(text: localizations.home_chants),
            Tab(text: localizations.session_mala),
            Tab(text: localizations.home_timer),
          ],
          labelStyle: context.tabLabelStyle(
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          unselectedLabelStyle: context.tabLabelStyle(
            const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          ),
          labelColor:
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          unselectedLabelColor:
              isDark ? AppColors.textTertiaryDark : AppColors.textSecondary,
          indicatorColor: Colors.blue,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlansTab(
            tab: _practiceTab,
            scrollController: _plansScrollController,
            enrollingItemId: _enrollingItemId,
            onItemSelected: _onPracticeItemSelected,
          ),
          _ChantsTab(
            scrollController: _chantsScrollController,
            enrollingItemId: _enrollingItemId,
            onRecitationSelected: _onRecitationSelected,
            searchQuery: '',
          ),
          _MalasTab(
            onMantraSelected: _onMantraSelected,
            searchQuery: '',
          ),
          _TimersTab(
            onTimerSelected: _onTimerSelected,
            searchQuery: '',
          ),
        ],
      ),
    );
  }
}

// ─── Plans tab ───────────────────────────────────────────────────────────────

class _PlansTab extends ConsumerWidget {
  final PracticeItemsTab tab;
  final ScrollController scrollController;
  final String? enrollingItemId;
  final void Function(PracticeItem item) onItemSelected;

  const _PlansTab({
    required this.tab,
    required this.scrollController,
    required this.enrollingItemId,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsState = ref.watch(practiceItemsPaginatedProvider(tab));

    Future<void> onRefresh() =>
        ref.read(practiceItemsPaginatedProvider(tab).notifier).refresh();

    _logger.debug(
      '📋 _PlansTab BUILD: ${itemsState.items.length} items, '
      'isLoading: ${itemsState.isLoading}, error: ${itemsState.error}',
    );

    if (itemsState.isLoading && itemsState.items.isEmpty) {
      return const PlanListSkeleton();
    }

    if (itemsState.error != null && itemsState.items.isEmpty) {
      return _RefreshableScrollBody(
        onRefresh: onRefresh,
        child: _SessionTabMessage(
          message: context.l10n.session_plans_load_error,
        ),
      );
    }

    final items = itemsState.items;

    if (items.isEmpty && !itemsState.isLoading) {
      return _RefreshableScrollBody(
        onRefresh: onRefresh,
        child: _SessionTabMessage(message: context.l10n.no_plans_found),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length + (itemsState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child:
                    itemsState.isLoadingMore
                        ? const CircularProgressIndicator()
                        : const SizedBox.shrink(),
              ),
            );
          }

          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildPlanCard(context, item),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, PracticeItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (item) {
      case PracticePlanItem(:final plan):
        final dateRange = _formatDateRange(
          plan.startDate,
          plan.startDate?.add(Duration(days: plan.totalDays)),
        );
        return _SessionCard(
          isDark: isDark,
          onTap: enrollingItemId == null ? () => onItemSelected(item) : null,
          child: Row(
            children: [
              _CoverImage(image: plan.coverImage, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateRange != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        dateRange,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

      case PracticeSeriesItem(:final series):
        final dateRange = _formatDateRange(series.startDate, series.endDate);
        final subtitle =
            series.subTitle?.isNotEmpty == true ? series.subTitle : dateRange;
        return _SessionCard(
          isDark: isDark,
          onTap: enrollingItemId == null ? () => onItemSelected(item) : null,
          child: Row(
            children: [
              _CoverImage(image: series.coverImage, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  static String? _formatDateRange(DateTime? start, DateTime? end) {
    return PlanDateFormat.formatRangeOrSingle(start, end);
  }
}

// ─── Chants tab ──────────────────────────────────────────────────────────────

class _ChantsTab extends ConsumerWidget {
  final ScrollController scrollController;
  final String? enrollingItemId;
  final void Function(RecitationModel recitation) onRecitationSelected;
  final String searchQuery;

  const _ChantsTab({
    required this.scrollController,
    required this.enrollingItemId,
    required this.onRecitationSelected,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(contentLanguageProvider);
    final query = searchQuery.trim();

    if (query.isNotEmpty) {
      if (query.length < 3) {
        return const SizedBox.shrink();
      }

      final searchState = ref.watch(practiceRecitationSearchProvider(languageCode));

      if (searchState.isLoading && searchState.results.isEmpty) {
        return const RecitationListSkeleton(
          variant: RecitationListSkeletonVariant.chantTile,
        );
      }

      if (searchState.error != null && searchState.results.isEmpty) {
        return _RefreshableScrollBody(
          onRefresh: () async {
            ref.read(practiceRecitationSearchProvider(languageCode).notifier).retry();
          },
          child: _SessionTabMessage(
            message: context.l10n.session_chants_load_error,
          ),
        );
      }

      final recitations = searchState.results;

      if (recitations.isEmpty && !searchState.isLoading) {
        return _RefreshableScrollBody(
          onRefresh: () async {
            ref.read(practiceRecitationSearchProvider(languageCode).notifier).retry();
          },
          child: _SessionTabMessage(
            message: context.l10n.search_no_results(query),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          ref.read(practiceRecitationSearchProvider(languageCode).notifier).retry();
        },
        child: ListView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: recitations.length,
          itemBuilder: (context, index) {
            final recitation = recitations[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PracticeChantListTile(
                recitation: recitation,
                showTrailingCaret: false,
                includeOuterPadding: false,
                onTap:
                    enrollingItemId == null
                        ? () => onRecitationSelected(recitation)
                        : null,
              ),
            );
          },
        ),
      );
    }

    final recitationsState = ref.watch(
      practiceRecitationsPaginatedProvider(languageCode),
    );

    Future<void> onRefresh() => ref
        .read(practiceRecitationsPaginatedProvider(languageCode).notifier)
        .refresh();

    if (recitationsState.isLoading && recitationsState.recitations.isEmpty) {
      return const RecitationListSkeleton(
        variant: RecitationListSkeletonVariant.chantTile,
      );
    }

    if (recitationsState.error != null &&
        recitationsState.recitations.isEmpty) {
      return _RefreshableScrollBody(
        onRefresh: onRefresh,
        child: _SessionTabMessage(
          message: context.l10n.session_chants_load_error,
        ),
      );
    }

    final recitations = recitationsState.recitations;

    if (recitations.isEmpty && !recitationsState.isLoading) {
      return _RefreshableScrollBody(
        onRefresh: onRefresh,
        child: _SessionTabMessage(message: context.l10n.session_no_chants),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: recitations.length + (recitationsState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == recitations.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child:
                    recitationsState.isLoadingMore
                        ? const CircularProgressIndicator()
                        : const SizedBox.shrink(),
              ),
            );
          }

          final recitation = recitations[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PracticeChantListTile(
              recitation: recitation,
              showTrailingCaret: false,
              includeOuterPadding: false,
              onTap:
                  enrollingItemId == null
                      ? () => onRecitationSelected(recitation)
                      : null,
            ),
          );
        },
      ),
    );
  }
}

// ─── Malas tab ───────────────────────────────────────────────────────────────

class _MalasTab extends ConsumerWidget {
  final void Function(Mantra mantra) onMantraSelected;
  final String searchQuery;

  const _MalasTab({
    required this.onMantraSelected,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final language = ref.watch(contentLanguageProvider);

    if (searchQuery.trim().isNotEmpty) {
      final searchState = ref.watch(accumulationSearchProvider);

      if (searchState.isLoading && searchState.results.isEmpty) {
        return const _MalaListSkeleton();
      }

      if (searchState.error != null && searchState.results.isEmpty) {
        return _RefreshableScrollBody(
          onRefresh: () async {
            ref.read(accumulationSearchProvider.notifier).retry();
          },
          child: _SessionTabMessage(
            message: context.l10n.session_malas_load_error,
          ),
        );
      }

      final mantras = searchState.results;

      if (mantras.isEmpty && !searchState.isLoading) {
        return _RefreshableScrollBody(
          onRefresh: () async {
            ref.read(accumulationSearchProvider.notifier).retry();
          },
          child: _SessionTabMessage(
            message: context.l10n.search_no_results(searchQuery.trim()),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          ref.read(accumulationSearchProvider.notifier).retry();
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          itemCount: mantras.length,
          itemBuilder: (context, index) {
            final mantra = mantras[index];
            final imageUrl = mantra.beadImageUrl ?? mantra.mantra?.beadImageUrl;
            final title = mantra.displayTitle(language);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SessionCard(
                isDark: isDark,
                onTap: () => onMantraSelected(mantra),
                child: Row(
                  children: [
                    _CircularImage(imageUrl: imageUrl, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final catalogueAsync = ref.watch(malaCatalogueProvider);
    Future<void> onRefresh() async {
      ref.invalidate(malaCatalogueProvider);
      await ref.read(malaCatalogueProvider.future);
    }

    return catalogueAsync.when(
      skipLoadingOnReload: true,
      loading: () => const _MalaListSkeleton(),
      error:
          (_, __) => _RefreshableScrollBody(
            onRefresh: onRefresh,
            child: _SessionTabMessage(
              message: context.l10n.session_malas_load_error,
            ),
          ),
      data:
          (either) => either.fold(
            (_) => _RefreshableScrollBody(
              onRefresh: onRefresh,
              child: _SessionTabMessage(
                message: context.l10n.session_malas_load_error,
              ),
            ),
            (mantras) {
              if (mantras.isEmpty) {
                return _RefreshableScrollBody(
                  onRefresh: onRefresh,
                  child: _SessionTabMessage(
                    message: context.l10n.session_no_malas,
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: mantras.length,
                  itemBuilder: (context, index) {
                    final mantra = mantras[index];
                    final imageUrl =
                        mantra.beadImageUrl ?? mantra.mantra?.beadImageUrl;
                    final title = mantra.displayTitle(language);
                    _logger.debug(
                      '🪬 Mala[$index] title=$title imageUrl=$imageUrl',
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionCard(
                        isDark: isDark,
                        onTap: () => onMantraSelected(mantra),
                        child: Row(
                          children: [
                            _CircularImage(imageUrl: imageUrl, size: 52),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
    );
  }
}

// ─── Timers tab ──────────────────────────────────────────────────────────────

class _TimersTab extends ConsumerWidget {
  final void Function(PresetTimer timer) onTimerSelected;
  final String searchQuery;

  const _TimersTab({
    required this.onTimerSelected,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context)!;
    final timersAsync = ref.watch(presetTimersFutureProvider);
    Future<void> onRefresh() async {
      ref.invalidate(presetTimersFutureProvider);
      await ref.read(presetTimersFutureProvider.future);
    }

    return timersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (_, __) => _RefreshableScrollBody(
            onRefresh: onRefresh,
            child: _SessionTabMessage(
              message: context.l10n.session_timers_load_error,
            ),
          ),
      data:
          (either) => either.fold(
            (_) => _RefreshableScrollBody(
              onRefresh: onRefresh,
              child: _SessionTabMessage(
                message: context.l10n.session_timers_load_error,
              ),
            ),
            (timers) {
              final query = searchQuery.trim();
              final filteredTimers = query.isEmpty
                  ? timers
                  : timers
                      .where((timer) =>
                          timer.name.toLowerCase().contains(query.toLowerCase()))
                      .toList();

              if (filteredTimers.isEmpty) {
                return _RefreshableScrollBody(
                  onRefresh: onRefresh,
                  child: _SessionTabMessage(
                    message:
                        query.isEmpty
                            ? context.l10n.session_no_timers
                            : context.l10n.search_no_results(query),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: filteredTimers.length,
                  itemBuilder: (context, index) {
                    final timer = filteredTimers[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionCard(
                        isDark: isDark,
                        onTap: () => onTimerSelected(timer),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppColors.surfaceVariantDark
                                        : AppColors.grey100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                PhosphorIconsRegular.timer,
                                size: 22,
                                color:
                                    isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${timer.displayValue} ${timer.displaysSeconds ? localizations.timer_duration_sec : localizations.timer_min}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
    );
  }
}

// ─── Shared card wrapper ──────────────────────────────────────────────────────

/// Makes pull-to-refresh work when tab content does not fill the viewport.
class _RefreshableScrollBody extends StatelessWidget {
  const _RefreshableScrollBody({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder:
            (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(height: constraints.maxHeight, child: child),
            ),
      ),
    );
  }
}

class _MalaListSkeleton extends StatelessWidget {
  const _MalaListSkeleton({this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SessionCard(
              isDark: isDark,
              child: const Row(
                children: [
                  Bone.circle(size: 52),
                  SizedBox(width: 12),
                  Expanded(
                    child: Bone(
                      width: 160,
                      height: 16,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SessionTabMessage extends StatelessWidget {
  const _SessionTabMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final VoidCallback? onTap;

  const _SessionCard({required this.child, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
  }
}

// ─── Shared image widgets ─────────────────────────────────────────────────────

/// Rounded-rectangle cover image or grey placeholder.
class _CoverImage extends StatelessWidget {
  final ResponsiveImage? image;
  final double size;

  const _CoverImage({this.image, required this.size});

  @override
  Widget build(BuildContext context) {
    if (image != null && !image!.isEmpty) {
      return ResponsiveCoverImage(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(8),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Circular image for malas — uses CachedNetworkImage so bead art renders
/// correctly (same approach as MalaBeads).
class _CircularImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _CircularImage({this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    if (url != null && url.isNotEmpty && _isValidNetworkUrl(url)) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final cachePx = _toCachePx(size, dpr);

      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: stableNetworkImageCacheKey(url),
          cacheManager: appImageCacheManager,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: cachePx,
          memCacheHeight: cachePx,
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 200),
          useOldImageOnUrlChange: true,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (context, url, error) {
            final sanitizedUrl = stableNetworkImageCacheKey(url);
            _logger.warning('Failed to load mala image: $sanitizedUrl, error: $error');
            return _placeholder();
          },
        ),
      );
    }
    return _placeholder();
  }

  bool _isValidNetworkUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority &&
        uri.host.isNotEmpty;
  }

  /// Converts a logical dimension to physical pixels for cache sizing. Returns
  /// null when the dimension is non-finite (e.g. `double.infinity`) or
  /// non-positive — in those cases the framework should decode at natural size.
  int? _toCachePx(double logical, double dpr) {
    if (!logical.isFinite || logical <= 0) return null;
    return (logical * dpr).round();
  }

  Widget _placeholder() => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.grey100,
      shape: BoxShape.circle,
    ),
  );
}
