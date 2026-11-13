import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/error/load_error_kind.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/localization/content_language_picker_sheet.dart';
import 'package:flutter_pecha/core/localization/languages_providers.dart';
import 'package:flutter_pecha/core/widgets/error_state_widget.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/audio_chants_see_all_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/chant_books_see_all_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/recitations_search_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/text_chants_see_all_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_actions.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_sections.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/recitation_reader_navigation.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_book_card.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_filter_pills.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_load_notice.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_section_header.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/space_chant_rows.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_pecha/features/recitation/presentation/widgets/recitation_list_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:fpdart/fpdart.dart';

/// The Chants page (#345): pills for All / Chant books / Single chants,
/// the user's chant books, space chant books and chants with audio grouped
/// by "From your spaces" and "Explore more", and the library's text-only
/// chants.
class AllRecitationsScreen extends ConsumerStatefulWidget {
  const AllRecitationsScreen({super.key});

  @override
  ConsumerState<AllRecitationsScreen> createState() =>
      _AllRecitationsScreenState();
}

class _AllRecitationsScreenState extends ConsumerState<AllRecitationsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _languageRestored = false;
  bool _isCreateFlowOpen = false;
  ChantsFilter _filter = ChantsFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Prefetch so the language picker usually opens already resolved.
    ref.read(recitationContentLanguagesProvider);
    _restoreLanguage();
  }

  // Waits for the persisted pick so the first page is not fetched in the app
  // language and immediately refetched.
  Future<void> _restoreLanguage() async {
    await ref
        .read(practiceRecitationsLanguageProvider.notifier)
        .ensureInitialized();
    if (!mounted) return;
    setState(() => _languageRestored = true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Only the Single chants pill lists the whole catalogue page by page.
  void _onScroll() {
    if (_filter != ChantsFilter.singleChants || !_languageRestored) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final languageCode = ref.read(practiceRecitationsLanguageProvider);
      ref
          .read(practiceRecitationsCatalogueProvider(languageCode).notifier)
          .loadMore();
    }
  }

  void _selectFilter(ChantsFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  // Both actions resolve the language themselves: tapping before the persisted
  // pick has loaded must not fall back to the app content language.
  Future<void> _openSearch() async {
    await _ensureLanguageRestored();
    if (!mounted) return;
    final languageCode = ref.read(practiceRecitationsLanguageProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'recitations-search'),
        builder: (_) => RecitationsSearchScreen(languageCode: languageCode),
      ),
    );
  }

  Future<void> _openLanguagePicker() async {
    await _ensureLanguageRestored();
    if (!mounted) return;
    final selectedCode = ref.read(practiceRecitationsLanguageProvider);
    showContentLanguagePickerSheet(
      context,
      selectedCode: selectedCode,
      recitationOnly: true,
      onSelected: (code) {
        ref
            .read(practiceRecitationsLanguageProvider.notifier)
            .setLanguage(code);
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
    );
  }

  Future<void> _ensureLanguageRestored() =>
      ref
          .read(practiceRecitationsLanguageProvider.notifier)
          .ensureInitialized();

  Future<void> _onCreateChantBookPressed() async {
    setState(() => _isCreateFlowOpen = true);
    try {
      await createChantBook(context, ref);
    } finally {
      // Restore the button even if the flow throws, not just when it ends.
      if (mounted) setState(() => _isCreateFlowOpen = false);
    }
  }

  void _openChantBook(ChantBook book) => openChantBook(context, ref, book);

  void _seeAllChantBooks(ChantBooksSeeAll list) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'chant-books-see-all'),
        builder: (_) => ChantBooksSeeAllScreen(list: list),
      ),
    );
  }

  void _seeAllAudioChants({required bool yours}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'audio-chants-see-all'),
        builder: (_) => AudioChantsSeeAllScreen(showYours: yours),
      ),
    );
  }

  void _seeAllTextChants({required bool yours}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'text-chants-see-all'),
        builder: (_) => TextChantsSeeAllScreen(showYours: yours),
      ),
    );
  }

  Future<void> _refresh() async {
    final languageCode = ref.read(practiceRecitationsLanguageProvider);
    ref.invalidate(myChantBooksProvider);
    ref.invalidate(spaceChantBooksProvider);
    await Future.wait([
      ref
          .read(practiceRecitationsCatalogueProvider(languageCode).notifier)
          .refresh(),
      ref.read(myChantBooksProvider.future),
      ref.read(spaceChantsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = ref.watch(practiceRecitationsLanguageProvider);
    final catalogue =
        _languageRestored
            ? ref.watch(practiceRecitationsCatalogueProvider(languageCode))
            : const PracticeRecitationsState(isLoading: true);
    final myBooks = ref.watch(myChantBooksProvider);
    final spaceBooks = ref.watch(spaceChantBooksProvider);
    final spaceChants = ref.watch(spaceChantsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppAssets.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.home_chants,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          strutStyle: context.tibetanStrutStyle(20),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(AppAssets.search),
            tooltip: l10n.recitations_search_for,
            onPressed: _openSearch,
          ),
          IconButton(
            icon: const Icon(AppAssets.language),
            tooltip: l10n.language,
            onPressed: _openLanguagePicker,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChantFilterPills(
            labels: [
              l10n.chants_filter_all,
              l10n.chants_chant_books,
              l10n.chants_filter_single_chants,
            ],
            selectedIndex: _filter.index,
            onSelected: (i) => _selectFilter(ChantsFilter.values[i]),
          ),
          Expanded(
            child: _buildBody(
              context,
              catalogue: catalogue,
              myBooks: myBooks,
              spaceBooks: spaceBooks,
              spaceChants: spaceChants,
              languageCode: languageCode,
            ),
          ),
        ],
      ),
      floatingActionButton:
          _isCreateFlowOpen
              ? null
              : ChantBookCreateButton(
                label: l10n.chants_create_chant_book,
                onPressed: _onCreateChantBookPressed,
              ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required PracticeRecitationsState catalogue,
    required AsyncValue<Either<Failure, ChantBooksPage>> myBooks,
    required AsyncValue<Either<Failure, SpaceChantBooks>> spaceBooks,
    required AsyncValue<Either<Failure, SpaceChants>> spaceChants,
    required String languageCode,
  }) {
    // A failed or loading source simply shows nothing; the page fails only
    // when nothing at all could be shown.
    final myList = _valueOrNull(myBooks)?.books ?? const <ChantBook>[];
    final spaces = _valueOrNull(spaceBooks) ?? SpaceChantBooks.empty;
    final chantsOfSpaces = _valueOrNull(spaceChants) ?? SpaceChants.empty;
    final chants = catalogue.recitations;

    final sections = [
      ...chantsPageSections(
        filter: _filter,
        hasMyChantBooks: myList.isNotEmpty,
        hasYourSpaceChantBooks: spaces.yours.isNotEmpty,
        hasOtherSpaceChantBooks: spaces.others.isNotEmpty,
        hasTextOnlyChants:
            chants.isNotEmpty || chantsOfSpaces.othersText.isNotEmpty,
        hasYourAudioChants: chantsOfSpaces.yoursAudio.isNotEmpty,
        hasOtherAudioChants: chantsOfSpaces.othersAudio.isNotEmpty,
        hasYourTextChants: chantsOfSpaces.yoursText.isNotEmpty,
      ),
    ];
    // The library failed while other sections show: keep a "Text only"
    // section so its error and retry are not lost under them. With no
    // other section the full error screen below says it.
    final catalogueMatters = _filter != ChantsFilter.chantBooks;
    if (catalogueMatters &&
        catalogue.error != null &&
        sections.isNotEmpty &&
        !sections.contains(ChantsSection.textOnlyChants)) {
      sections.add(ChantsSection.textOnlyChants);
    }

    final stillLoading =
        catalogue.isLoading ||
        myBooks.isLoading ||
        spaceBooks.isLoading ||
        spaceChants.isLoading;
    if (sections.isEmpty) {
      if (stillLoading) {
        return const RecitationListSkeleton(
          variant: RecitationListSkeletonVariant.chantTile,
        );
      }
      if (catalogueMatters && catalogue.error != null) {
        return _catalogueError(context, catalogue, languageCode);
      }
      final bookFailure = _failureOf(spaceBooks) ?? _failureOf(myBooks);
      if (!catalogueMatters && bookFailure != null) {
        return ErrorStateWidget(
          error: bookFailure.message,
          onRetry: () {
            ref.invalidate(myChantBooksProvider);
            ref.invalidate(spaceChantBooksProvider);
          },
        );
      }
      return Center(child: Text(context.l10n.recitations_no_content));
    }

    // The books are in but their chants are still loading: hold their place
    // under the first space rail so the page doesn't jump when they land.
    final chantsPending =
        _filter != ChantsFilter.chantBooks &&
        spaceChants.isLoading &&
        _valueOrNull(spaceBooks) != null;
    final placeholderAfter =
        !chantsPending
            ? null
            : sections.contains(ChantsSection.yourSpaceChantBooks)
            ? ChantsSection.yourSpaceChantBooks
            : sections.contains(ChantsSection.otherSpaceChantBooks)
            ? ChantsSection.otherSpaceChantBooks
            : null;

    // A source failed or came back short while other sections show: say
    // so above them, with Retry, rather than leaving its chants out
    // quietly. (With nothing to show, the full error screen above says it.)
    final myBooksFailed = _failed(myBooks);
    final spacesShort =
        _failed(spaceBooks) ||
        spaces.isPartial ||
        (catalogueMatters &&
            (_failed(spaceChants) || chantsOfSpaces.isPartial));

    final items = <Widget>[
      if (myBooksFailed || spacesShort)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ChantLoadNotice(
            message: context.l10n.unableToLoad,
            onRetry: () {
              if (myBooksFailed) ref.invalidate(myChantBooksProvider);
              if (spacesShort) ref.invalidate(spaceChantBooksProvider);
            },
          ),
        ),
      if (chantsPending && placeholderAfter == null)
        const _SpaceChantsPlaceholder(),
    ];
    for (final section in sections) {
      items.addAll(
        _sectionItems(
          context,
          section,
          myBooks: myList,
          spaces: spaces,
          spaceChants: chantsOfSpaces,
          catalogue: catalogue,
          languageCode: languageCode,
        ),
      );
      if (section == placeholderAfter) {
        items.add(const _SpaceChantsPlaceholder());
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        // Room under the last row for the Chant book button.
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    );
  }

  List<Widget> _sectionItems(
    BuildContext context,
    ChantsSection section, {
    required List<ChantBook> myBooks,
    required SpaceChantBooks spaces,
    required SpaceChants spaceChants,
    required PracticeRecitationsState catalogue,
    required String languageCode,
  }) {
    final l10n = context.l10n;
    // Under the Chant books pill the two space rails are titled by where
    // they come from; elsewhere a group heading above says it.
    final railsTitledBySpace =
        _filter == ChantsFilter.chantBooks && spaces.hasYourSpaces;
    switch (section) {
      case ChantsSection.myChantBooks:
        return [
          ChantSectionHeader(
            title: l10n.chants_my_chant_books,
            // The design has no See all while the rail holds two or fewer.
            onSeeAll:
                myBooks.length > 2
                    ? () => _seeAllChantBooks(ChantBooksSeeAll.mine)
                    : null,
          ),
          _ChantBookRail(books: myBooks, onTap: _openChantBook),
        ];
      case ChantsSection.yourSpacesHeading:
        return [ChantGroupHeading(l10n.chants_from_your_spaces)];
      case ChantsSection.yourSpaceChantBooks:
        return [
          ChantSectionHeader(
            title:
                railsTitledBySpace
                    ? l10n.chants_from_your_spaces
                    : l10n.chants_chant_books,
            onSeeAll: () => _seeAllChantBooks(ChantBooksSeeAll.yourSpaces),
          ),
          _ChantBookRail(books: spaces.yours, onTap: _openChantBook),
        ];
      case ChantsSection.yourAudioChants:
        return _audioItems(
          context,
          spaceChants.yoursAudio,
          isNewUser: !spaces.hasYourSpaces,
          onSeeAll: () => _seeAllAudioChants(yours: true),
        );
      case ChantsSection.exploreMoreHeading:
        return [ChantGroupHeading(l10n.chants_explore_more)];
      case ChantsSection.otherSpaceChantBooks:
        return [
          ChantSectionHeader(
            title:
                railsTitledBySpace
                    ? l10n.chants_explore_more
                    : l10n.chants_chant_books,
            onSeeAll: () => _seeAllChantBooks(ChantBooksSeeAll.otherSpaces),
          ),
          _ChantBookRail(books: spaces.others, onTap: _openChantBook),
        ];
      case ChantsSection.otherAudioChants:
        return _audioItems(
          context,
          spaceChants.othersAudio,
          isNewUser: !spaces.hasYourSpaces,
          onSeeAll: () => _seeAllAudioChants(yours: false),
        );
      case ChantsSection.yourTextChants:
        final limit = chantsRowLimit(_filter);
        final yoursText = spaceChants.yoursText;
        return [
          ChantSectionHeader(
            title: l10n.chants_text_only,
            onSeeAll:
                yoursText.length > limit
                    ? () => _seeAllTextChants(yours: true)
                    : null,
          ),
          for (final chant in yoursText.take(limit))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SpaceTextChantRow(chant: chant),
            ),
        ];
      case ChantsSection.textOnlyChants:
        // Other spaces' chants first, then the library's.
        final isFullList = _filter == ChantsFilter.singleChants;
        final othersText = spaceChants.othersText;
        final total = othersText.length + catalogue.recitations.length;
        final shown = isFullList ? total : min(total, chantsAllTextOnlyLimit);
        final showSeeAll =
            !isFullList &&
            (total > chantsAllTextOnlyLimit || catalogue.hasMore);
        return [
          ChantSectionHeader(
            title: l10n.chants_text_only,
            onSeeAll: showSeeAll ? () => _seeAllTextChants(yours: false) : null,
          ),
          for (var i = 0; i < shown; i++)
            if (i < othersText.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SpaceTextChantRow(chant: othersText[i]),
              )
            else
              _TextChantItem(
                recitation: catalogue.recitations[i - othersText.length],
                openLabel: l10n.chants_open_chant,
                onTap:
                    () => openRecitationReader(
                      context,
                      catalogue.recitations[i - othersText.length],
                      listLanguage: languageCode,
                    ),
              ),
          if (isFullList && catalogue.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          // The library failed, on its first page or a later one: an
          // error with Retry in its place, so the chants are not just
          // missing. (A failed later page never pages on scroll again.)
          else if (catalogue.error != null &&
              (isFullList || catalogue.recitations.isEmpty))
            ChantLoadNotice(
              message: catalogue.error!,
              onRetry: () {
                final notifier = ref.read(
                  practiceRecitationsCatalogueProvider(languageCode).notifier,
                );
                if (catalogue.recitations.isEmpty) {
                  notifier.retry();
                } else {
                  notifier.loadMore();
                }
              },
            ),
        ];
    }
  }

  /// A "Chants with audio" header and the first few rows; a new user's
  /// single list is titled "Audio chants", as in the design.
  List<Widget> _audioItems(
    BuildContext context,
    List<SpaceChant> chants, {
    required bool isNewUser,
    required VoidCallback onSeeAll,
  }) {
    final l10n = context.l10n;
    final limit = chantsRowLimit(_filter);
    return [
      ChantSectionHeader(
        title: isNewUser ? l10n.chants_audio_chants : l10n.chants_with_audio,
        onSeeAll: chants.length > limit ? onSeeAll : null,
      ),
      for (final chant in chants.take(limit))
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SpaceAudioChantRow(chant: chant),
        ),
    ];
  }

  Widget _catalogueError(
    BuildContext context,
    PracticeRecitationsState state,
    String languageCode,
  ) {
    final l10n = context.l10n;
    // Says what went wrong: no connection, the server or the app's setup,
    // or nothing there.
    final (title, message) = switch (state.errorKind) {
      LoadErrorKind.connection => (l10n.error_offline_title, l10n.unableToLoad),
      LoadErrorKind.server => (
        l10n.error_server_title,
        l10n.chants_error_server_message,
      ),
      LoadErrorKind.missing => (null, l10n.noContentAvailable),
      null => (null, null),
    };
    return ErrorStateWidget(
      error: state.error!,
      customTitle: title,
      customMessage: message,
      onRetry: () {
        ref
            .read(practiceRecitationsCatalogueProvider(languageCode).notifier)
            .retry();
        ref.invalidate(myChantBooksProvider);
        ref.invalidate(spaceChantBooksProvider);
      },
    );
  }
}

T? _valueOrNull<T>(AsyncValue<Either<Failure, T>> value) =>
    value.valueOrNull?.fold((_) => null, (data) => data);

Failure? _failureOf<T>(AsyncValue<Either<Failure, T>> value) =>
    value.valueOrNull?.fold((failure) => failure, (_) => null);

/// True once a read ended in a failure, returned or thrown.
bool _failed<T>(AsyncValue<Either<Failure, T>> value) =>
    !value.isLoading && (value.hasError || _failureOf(value) != null);

/// Shimmering audio rows standing in for the space chant sections while
/// the books' chants load.
class _SpaceChantsPlaceholder extends StatelessWidget {
  const _SpaceChantsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Bone.text(words: 3, fontSize: 18),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: AudioChantRow(
                  title: 'Chant title loading',
                  playLabel: '',
                  reciterLine: 'Reciter name',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal row of chant book cards.
class _ChantBookRail extends StatelessWidget {
  const _ChantBookRail({required this.books, required this.onTap});

  final List<ChantBook> books;
  final ValueChanged<ChantBook> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ChantBookCard.railHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final book = books[index];
          return Align(
            alignment: Alignment.topCenter,
            child: ChantBookCard(
              name: book.name,
              chantCount: book.chantCount,
              subtitle: book.subtitle,
              imageUrl: book.imageUrl ?? book.groupAvatarUrl,
              hasAudio: book.hasAudio,
              onTap: () => onTap(book),
            ),
          );
        },
      ),
    );
  }
}

class _TextChantItem extends StatelessWidget {
  const _TextChantItem({
    required this.recitation,
    required this.openLabel,
    required this.onTap,
  });

  final RecitationModel recitation;
  final String openLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: TextChantRow(
        title: recitation.title,
        openLabel: openLabel,
        language: recitation.language,
        firstVerse: recitation.firstSegment?.content,
        onTap: onTap,
      ),
    );
  }
}
