import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/search_analytics.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/home/domain/entities/series.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_beads.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_explore_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_search_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_spaces_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/series_search_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_sections.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/recitation_reader_navigation.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_book_card.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_load_notice.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/space_chant_rows.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_chant_list_tile.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_plan_card.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_container.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_space_cards.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_spaces_section.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:go_router/go_router.dart';

/// Search on the Practice tab. There is no one search endpoint, so each
/// existing search runs on the same query and the results show by
/// section: Plans (catalog search, then space plans), Malas (the mala
/// catalogue search), Space accumulations, Chant books, Audio chants and
/// Text-only chants (as the Chants page search finds them).
///
/// Space plans and accumulations are matched on the device: the spaces
/// feed's `search` only matches chant book names.
///
/// Before a query it lists the recent searches; with nothing found it
/// shows popular chants.
class PracticeSearchScreen extends ConsumerStatefulWidget {
  const PracticeSearchScreen({super.key});

  @override
  ConsumerState<PracticeSearchScreen> createState() =>
      _PracticeSearchScreenState();
}

class _PracticeSearchScreenState extends ConsumerState<PracticeSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// The query once typing pauses; what the non-debounced searches use.
  String _query = '';
  Timer? _debounce;

  /// Whether the settled query found anything, for the recent list.
  bool _found = false;

  /// The settled query whose result count was reported, so each query is
  /// reported once, when every section has answered.
  String? _trackedQuery;

  /// A query the user submitted with the keyboard, saved to the recent
  /// list once its results are in rather than at the keypress, when the
  /// debounce may still hold the previous query.
  String? _submitted;

  late final String _language = ref.read(contentLanguageProvider);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The plan and mala searches outlive this screen; start them empty.
      ref.read(seriesSearchProvider.notifier).clear();
      ref.read(accumulationSearchProvider.notifier).clear();
      _focusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A result opened on top (or the screen is left): keep the query.
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) _remember();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final trimmed = text.trim();
    final active = trimmed.length >= chantsSearchMinQueryLength;
    final series = ref.read(seriesSearchProvider.notifier);
    final malas = ref.read(accumulationSearchProvider.notifier);
    final chants = ref.read(
      practiceRecitationSearchProvider(_language).notifier,
    );
    if (active) {
      series.search(trimmed);
      malas.search(trimmed);
      chants.search(trimmed);
    } else {
      series.clear();
      malas.clear();
      chants.clear();
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _query = active ? trimmed : '');
    });
  }

  /// Search pressed on the keyboard: settle the typed query now instead of
  /// after the debounce, and remember it once its results have answered.
  void _onSubmitted(String text) {
    final trimmed = text.trim();
    _debounce?.cancel();
    if (trimmed.length < chantsSearchMinQueryLength) return;
    setState(() {
      _query = trimmed;
      _submitted = trimmed;
    });
  }

  void _runRecent(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _onChanged(query);
    _debounce?.cancel();
    setState(() => _query = query.trim());
    _focusNode.unfocus();
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
    _debounce?.cancel();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  /// Reports a settled query once, with how many results every section
  /// found together. The plan and mala searches also report their own
  /// surfaces from their providers, as on their own screens.
  void _trackSearched(int resultCount) {
    final query = _query;
    if (query.isEmpty || _trackedQuery == query) return;
    _trackedQuery = query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(searchAnalyticsProvider)
          .searched(
            surface: SearchSurface.practice,
            query: query,
            resultCount: resultCount,
          );
    });
  }

  void _trackResultOpened(
    int position, {
    required String itemType,
    required String itemId,
  }) {
    ref
        .read(searchAnalyticsProvider)
        .resultOpened(
          surface: SearchSurface.practice,
          position: position,
          itemType: itemType,
          itemId: itemId,
        );
  }

  /// Saves the settled query to the recent list when it found something.
  /// Called from didChangeDependencies too, so the save waits for the
  /// frame: a provider cannot change while the tree builds.
  void _remember() {
    if (_query.isEmpty || !_found) return;
    final recent = ref.read(practiceRecentSearchesProvider.notifier);
    final query = _query;
    Future.microtask(() => recent.add(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.grey300;
    final hintColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    // Watched before a query too, so the autoDispose search the field
    // writes to stays alive between keystrokes.
    ref.watch(practiceRecitationSearchProvider(_language));
    final hasQuery =
        _controller.text.trim().length >= chantsSearchMinQueryLength;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(AppAssets.arrowLeft),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onChanged,
                      onSubmitted: _onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: l10n.practice_search_hint,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: hintColor,
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          AppAssets.search,
                          size: 20,
                          color: hintColor,
                        ),
                        suffixIcon:
                            _controller.text.isNotEmpty
                                ? IconButton(
                                  onPressed: _clear,
                                  tooltip:
                                      MaterialLocalizations.of(
                                        context,
                                      ).clearButtonTooltip,
                                  icon: Icon(
                                    AppAssets.x,
                                    size: 20,
                                    color: hintColor,
                                  ),
                                )
                                : null,
                        filled: true,
                        fillColor:
                            isDark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceWhite,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        enabledBorder: _pill(borderColor),
                        focusedBorder: _pill(borderColor),
                        border: _pill(borderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  hasQuery
                      ? _buildResults(context)
                      : _RecentSearches(onTap: _runRecent),
            ),
          ],
        ),
      ),
    );
  }

  static OutlineInputBorder _pill(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(999),
    borderSide: BorderSide(color: color),
  );

  Widget _buildResults(BuildContext context) {
    final l10n = context.l10n;
    final typed = _controller.text.trim();
    final queryPending = _query != typed;

    final seriesState = ref.watch(seriesSearchProvider);
    final malaState = ref.watch(accumulationSearchProvider);
    final chantState = ref.watch(practiceRecitationSearchProvider(_language));
    final spacePlansAsync = ref.watch(
      practiceSpaceSearchProvider((row: PracticeSpaceRow.plans, query: _query)),
    );
    final spaceAccAsync = ref.watch(
      practiceSpaceSearchProvider((
        row: PracticeSpaceRow.accumulations,
        query: _query,
      )),
    );
    final booksAsync = ref.watch(chantBookSearchProvider(_query));
    // Every space chant, filtered here to the search's language rather than
    // the Chants page's saved one, so both chant sources agree.
    final spaceChantsAsync = ref.watch(allSpaceChantsProvider);

    final catalogPlans = seriesState.results;
    final spacePlans = _list(spacePlansAsync);
    final malas = malaState.results;
    final spaceAccumulations = _list(spaceAccAsync);
    final books = _list(booksAsync);
    final spaceChants = spaceChantsAsync.valueOrNull?.fold(
      (_) => null,
      (c) => c.inLanguage(_language),
    );
    final spaceMatches =
        spaceChants == null || _query.isEmpty
            ? (audio: const <SpaceChant>[], text: const <SpaceChant>[])
            : matchSpaceChants(spaceChants, _query);
    final textChants = chantState.results;

    final hasPlans = catalogPlans.isNotEmpty || spacePlans.isNotEmpty;
    final hasText = spaceMatches.text.isNotEmpty || textChants.isNotEmpty;
    _found =
        hasPlans ||
        malas.isNotEmpty ||
        spaceAccumulations.isNotEmpty ||
        books.isNotEmpty ||
        spaceMatches.audio.isNotEmpty ||
        hasText;

    // Per section: still loading while its query has not settled or one
    // of its searches runs. A section with results shows them; a loading
    // one shows its title over a skeleton; a finished empty one is left
    // out, so the user sees which sections are still coming.
    final plansLoading =
        queryPending || seriesState.isLoading || spacePlansAsync.isLoading;
    final malasLoading = malaState.isLoading;
    final accumulationsLoading = queryPending || spaceAccAsync.isLoading;
    final booksLoading = queryPending || booksAsync.isLoading;
    final audioLoading = queryPending || spaceChantsAsync.isLoading;
    final textLoading =
        queryPending || chantState.isLoading || spaceChantsAsync.isLoading;
    final anyLoading =
        plansLoading ||
        malasLoading ||
        accumulationsLoading ||
        booksLoading ||
        audioLoading ||
        textLoading;

    // A search that failed, or space chants read with some books missing:
    // what was found may be incomplete, so a retry is offered.
    final failed =
        !queryPending &&
        (seriesState.error != null ||
            malaState.error != null ||
            chantState.error != null ||
            _failed(spacePlansAsync) ||
            _failed(spaceAccAsync) ||
            _failed(booksAsync) ||
            _failed(spaceChantsAsync) ||
            (spaceChants?.isPartial ?? false));

    if (!anyLoading && _submitted == _query) {
      _submitted = null;
      _remember();
    }

    if (!anyLoading) {
      _trackSearched(
        catalogPlans.length +
            spacePlans.length +
            malas.length +
            spaceAccumulations.length +
            books.length +
            spaceMatches.audio.length +
            spaceMatches.text.length +
            textChants.length,
      );
    }

    if (!_found && !anyLoading) {
      if (failed) return _SearchError(onRetry: _retry);
      return _NoResults(query: typed);
    }

    Widget section(String title, Widget child) => PracticeSectionContainer(
      title: title,
      isSubsection: true,
      child: child,
    );

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (failed && !anyLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ChantLoadNotice(
              message: l10n.unableToLoad,
              onRetry: _retry,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        if (hasPlans)
          section(
            l10n.home_shortcut_plans,
            _PlanRail(
              catalog: catalogPlans,
              spaces: spacePlans,
              onCatalogOpened:
                  (position, series) => _trackResultOpened(
                    position,
                    itemType: 'series',
                    itemId: series.id,
                  ),
            ),
          )
        else if (plansLoading)
          section(
            l10n.home_shortcut_plans,
            _CardRailSkeleton(height: practicePlanRailHeight(context)),
          ),
        if (malas.isNotEmpty)
          section(
            l10n.session_mala,
            _MalaRail(
              mantras: malas,
              language: _language,
              onOpened:
                  (position, mantra) => _trackResultOpened(
                    position,
                    itemType: 'mantra',
                    itemId: mantra.presetId,
                  ),
            ),
          )
        else if (malasLoading)
          section(l10n.session_mala, const _BeadRailSkeleton()),
        if (spaceAccumulations.isNotEmpty)
          section(
            l10n.practice_space_accumulations,
            PracticeSpaceAccumulatorRail(practices: spaceAccumulations),
          )
        else if (accumulationsLoading)
          section(
            l10n.practice_space_accumulations,
            const _CardRailSkeleton(
              height: PracticeSpaceAccumulatorCard.railImageHeight + 110,
            ),
          ),
        if (books.isNotEmpty)
          section(l10n.chants_chant_books, PracticeChantBookRail(books: books))
        else if (booksLoading)
          section(
            l10n.chants_chant_books,
            _CardRailSkeleton(
              height: ChantBookCard.railHeight(context),
              cardWidth: ChantBookCard.railWidth,
              cardHeight: ChantBookCard.railWidth,
              spacing: 10,
            ),
          ),
        if (spaceMatches.audio.isNotEmpty)
          section(
            l10n.chants_audio_chants,
            Column(
              children: [
                for (final (i, chant) in spaceMatches.audio.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SpaceAudioChantRow(
                      chant: chant,
                      onOpened:
                          () => _trackResultOpened(
                            i,
                            itemType: 'space_audio_chant',
                            itemId: chant.item.textId,
                          ),
                    ),
                  ),
              ],
            ),
          )
        else if (audioLoading)
          section(l10n.chants_audio_chants, const _RowListSkeleton()),
        if (hasText)
          section(
            l10n.chants_text_only,
            Column(
              children: [
                for (final (i, chant) in spaceMatches.text.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SpaceTextChantRow(
                      chant: chant,
                      onOpened:
                          () => _trackResultOpened(
                            i,
                            itemType: 'space_chant',
                            itemId: chant.item.textId,
                          ),
                    ),
                  ),
                for (final (i, chant) in textChants.indexed)
                  _textChantRow(context, chant, spaceMatches.text.length + i),
              ],
            ),
          )
        else if (textLoading)
          section(l10n.chants_text_only, const _RowListSkeleton()),
      ],
    );
  }

  Widget _textChantRow(
    BuildContext context,
    RecitationModel chant,
    int position,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextChantRow(
        title: chant.title,
        openLabel: context.l10n.chants_open_chant,
        language: chant.language,
        firstVerse: chant.firstSegment?.content,
        onTap: () {
          _trackResultOpened(position, itemType: 'chant', itemId: chant.textId);
          openRecitationReader(context, chant, listLanguage: _language);
        },
      ),
    );
  }

  void _retry() {
    ref.read(seriesSearchProvider.notifier).retry();
    ref.read(accumulationSearchProvider.notifier).retry();
    ref.read(practiceRecitationSearchProvider(_language).notifier).retry();
    ref.invalidate(practiceSpaceFeedProvider);
    // Re-reads the space books, and with them the space chants and the
    // chant book search.
    ref.invalidate(spaceChantBooksProvider);
    ref.invalidate(allSpaceChantsProvider);
    ref.invalidate(chantBookSearchProvider(_query));
  }

  static List<T> _list<T>(AsyncValue<Either<Failure, List<T>>> async) =>
      async.valueOrNull?.fold((_) => <T>[], (list) => list) ?? <T>[];

  static bool _failed<T>(AsyncValue<Either<Failure, T>> async) {
    if (async.isLoading) return false;
    if (async.hasError) return true;
    return async.valueOrNull?.isLeft() ?? false;
  }
}

/// Recent searches, newest first; tap runs one again, x removes it.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(practiceRecentSearchesProvider);
    if (recent.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(
            context.l10n.practice_search_recent,
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
        for (final query in recent)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 20, right: 8),
            leading: Icon(Icons.history, size: 20, color: muted),
            minLeadingWidth: 20,
            title: Text(
              query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
            trailing: IconButton(
              icon: Icon(AppAssets.x, size: 18, color: muted),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed:
                  () => ref
                      .read(practiceRecentSearchesProvider.notifier)
                      .remove(query),
            ),
            onTap: () => onTap(query),
          ),
      ],
    );
  }
}

/// Catalog plans, then space plans, in one rail.
class _PlanRail extends StatelessWidget {
  const _PlanRail({
    required this.catalog,
    required this.spaces,
    required this.onCatalogOpened,
  });

  final List<Series> catalog;
  final List<GroupPractice> spaces;

  /// A catalog series was opened, with its place in the rail.
  final void Function(int position, Series series) onCatalogOpened;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: practicePlanRailHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: catalog.length + spaces.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index < catalog.length) {
            final series = catalog[index];
            return Align(
              alignment: Alignment.topCenter,
              child: PracticePlanCard(
                series: series,
                onTap: () {
                  onCatalogOpened(index, series);
                  context.pushNamed(
                    'home-series-detail',
                    pathParameters: {'id': series.id},
                  );
                },
              ),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: PracticeSpacePlanCard(
              practice: spaces[index - catalog.length],
            ),
          );
        },
      ),
    );
  }
}

/// Mala catalogue matches as beads; a tap opens the counter on that mantra.
class _MalaRail extends ConsumerWidget {
  const _MalaRail({
    required this.mantras,
    required this.language,
    required this.onOpened,
  });

  final List<Mantra> mantras;
  final String language;

  /// A mantra was opened, with its place in the rail.
  final void Function(int position, Mantra mantra) onOpened;

  static const double _beadSize = 44;
  static const double _itemWidth = 84;

  void _open(BuildContext context, WidgetRef ref, int index, Mantra mantra) {
    if (ref.read(authProvider).isGuest) {
      LoginDrawer.show(context, ref, feature: 'mala');
      return;
    }
    onOpened(index, mantra);
    context.push(
      '/mala',
      extra: {
        'presetId': mantra.presetId,
        'source': MalaOpenSource.practiceTab,
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaler = MediaQuery.textScalerOf(context);
    return SizedBox(
      height: _beadSize + 8 + scaler.scale(32),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: mantras.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final mantra = mantras[index];
          final url = mantra.beadImageUrl?.trim() ?? '';
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(context, ref, index, mantra),
            child: SizedBox(
              width: _itemWidth,
              child: Column(
                children: [
                  url.isEmpty
                      ? const MalaBeadPreview(size: _beadSize)
                      : ClipOval(
                        child: CachedNetworkImageWidget(
                          imageUrl: url,
                          width: _beadSize,
                          height: _beadSize,
                        ),
                      ),
                  const SizedBox(height: 8),
                  Text(
                    mantra.displayTitle(language),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.25),
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

/// "No results for …" and the Practice tab's chants as popular practices.
class _NoResults extends ConsumerWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;
    final popular =
        ref
            .watch(practiceExploreRecitationsProvider)
            .valueOrNull
            ?.fold((_) => null, (page) => page.recitations) ??
        const [];

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            l10n.practice_search_no_results(query),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: muted),
          ),
        ),
        if (popular.isNotEmpty)
          PracticeSectionContainer(
            title: l10n.practice_popular_practices,
            isSubsection: true,
            child: Column(
              children: [
                for (final r in popular)
                  PracticeChantListTile(
                    recitation: r,
                    onTap: () => openRecitationReader(context, r),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.unableToLoad, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

/// Grey cards in a rail, the shape of the section's cards.
class _CardRailSkeleton extends StatelessWidget {
  const _CardRailSkeleton({
    required this.height,
    this.cardWidth = 300,
    this.cardHeight,
    this.spacing = 12,
  });

  final double height;
  final double cardWidth;

  /// Defaults to the rail's height.
  final double? cardHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, _) => SizedBox(width: spacing),
          itemBuilder:
              (_, _) => Align(
                alignment: Alignment.topCenter,
                child: Bone(
                  width: cardWidth,
                  height: cardHeight ?? height,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
        ),
      ),
    );
  }
}

/// Beads with a name under each, as the Malas row draws them.
class _BeadRailSkeleton extends StatelessWidget {
  const _BeadRailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: _MalaRail._beadSize + 8 + 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder:
              (_, _) => SizedBox(
                width: _MalaRail._itemWidth,
                child: Column(
                  children: [
                    Bone.circle(size: _MalaRail._beadSize),
                    const SizedBox(height: 8),
                    Bone(
                      width: 56,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

/// Two chant rows.
class _RowListSkeleton extends StatelessWidget {
  const _RowListSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Skeletonizer(
      enabled: true,
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardBackgroundDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Bone.square(
                      size: 44,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone(
                            width: 160,
                            height: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Bone(
                            width: 100,
                            height: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    Bone.circle(size: 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
