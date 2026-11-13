import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/localization/content_language_picker_sheet.dart';
import 'package:flutter_pecha/core/widgets/error_state_widget.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/recitations_search_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_actions.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/recitation_reader_navigation.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_filter_pills.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_load_notice.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_section_header.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/space_chant_rows.dart';
import 'package:flutter_pecha/features/recitation/presentation/widgets/recitation_list_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// See all for text-only chants, with the Your spaces / Other spaces pills.
///
/// Your spaces lists the chants of your spaces' chant books. Other spaces
/// lists other spaces' chants, then the whole library list page by page,
/// as under "Explore more" on the Chants page. With no text-only chants in
/// your spaces there are no pills.
class TextChantsSeeAllScreen extends ConsumerStatefulWidget {
  const TextChantsSeeAllScreen({super.key, this.showYours = false});

  /// Opens on your spaces; false opens on other spaces.
  final bool showYours;

  @override
  ConsumerState<TextChantsSeeAllScreen> createState() =>
      _TextChantsSeeAllScreenState();
}

class _TextChantsSeeAllScreenState
    extends ConsumerState<TextChantsSeeAllScreen> {
  final ScrollController _scrollController = ScrollController();
  late bool _showYours = widget.showYours;
  bool _isCreateFlowOpen = false;

  /// Whether the Your spaces list is on screen, set each build.
  bool _onYours = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Only the library list pages.
  void _onScroll() {
    if (_onYours) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final languageCode = ref.read(practiceRecitationsLanguageProvider);
      ref
          .read(practiceRecitationsCatalogueProvider(languageCode).notifier)
          .loadMore();
    }
  }

  void _openSearch() {
    final languageCode = ref.read(practiceRecitationsLanguageProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'recitations-search'),
        builder: (_) => RecitationsSearchScreen(languageCode: languageCode),
      ),
    );
  }

  void _openLanguagePicker() {
    showContentLanguagePickerSheet(
      context,
      selectedCode: ref.read(practiceRecitationsLanguageProvider),
      recitationOnly: true,
      onSelected: (code) {
        ref
            .read(practiceRecitationsLanguageProvider.notifier)
            .setLanguage(code);
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      },
    );
  }

  Future<void> _create() async {
    setState(() => _isCreateFlowOpen = true);
    try {
      await createChantBook(context, ref);
    } finally {
      if (mounted) setState(() => _isCreateFlowOpen = false);
    }
  }

  Future<void> _refresh() async {
    final languageCode = ref.read(practiceRecitationsLanguageProvider);
    ref.invalidate(spaceChantBooksProvider);
    await Future.wait([
      ref
          .read(practiceRecitationsCatalogueProvider(languageCode).notifier)
          .refresh(),
      ref.read(spaceChantsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Opened from the Chants page, which already restored the language.
    final languageCode = ref.watch(practiceRecitationsLanguageProvider);
    final provider = practiceRecitationsCatalogueProvider(languageCode);
    final state = ref.watch(provider);
    final spaceChantsAsync = ref.watch(spaceChantsProvider);
    // A failed space read still leaves the library list.
    final spaceChants =
        spaceChantsAsync.valueOrNull?.fold((_) => null, (c) => c) ??
        SpaceChants.empty;

    // The pills follow the chants in every language, so a language with
    // none in the user's spaces empties the list but keeps the pills.
    final hasYours =
        ref
            .watch(allSpaceChantsProvider)
            .valueOrNull
            ?.fold((_) => null, (all) => all.yoursText.isNotEmpty) ??
        _showYours;
    final showYours = hasYours && _showYours;
    _onYours = showYours;
    final othersText = spaceChants.othersText;
    final spacesLoading = spaceChantsAsync.isLoading;

    // The space chants failed, or some chant books could not be read:
    // said above either list, so they are not simply missing.
    final spacesFailed =
        !spaceChantsAsync.isLoading &&
        (spaceChantsAsync.hasError ||
            (spaceChantsAsync.valueOrNull?.isLeft() ?? false));
    final spacesNotice =
        spacesFailed || spaceChants.isPartial
            ? ChantLoadNotice(
              message: l10n.unableToLoad,
              onRetry: () => ref.invalidate(spaceChantBooksProvider),
              padding: EdgeInsets.zero,
            )
            : null;
    final lead = spacesNotice == null ? 0 : 1;

    final Widget list;
    if (showYours) {
      final yours = spaceChants.yoursText;
      list =
          yours.isEmpty
              ? _empty(l10n.recitations_no_content, notice: spacesNotice)
              : _rows(
                itemCount: yours.length + lead,
                itemBuilder:
                    (context, index) =>
                        index < lead
                            ? spacesNotice!
                            : SpaceTextChantRow(chant: yours[index - lead]),
              );
    } else if ((state.isLoading || spacesLoading) &&
        state.recitations.isEmpty &&
        othersText.isEmpty) {
      list = const RecitationListSkeleton(
        variant: RecitationListSkeletonVariant.chantTile,
      );
    } else if (state.error != null &&
        state.recitations.isEmpty &&
        othersText.isEmpty) {
      list = ErrorStateWidget(
        error: state.error!,
        onRetry: () {
          ref.read(provider.notifier).retry();
          if (spacesFailed) ref.invalidate(spaceChantBooksProvider);
        },
      );
    } else if (state.recitations.isEmpty && othersText.isEmpty) {
      list = _empty(l10n.recitations_no_content, notice: spacesNotice);
    } else {
      final chants = state.recitations;
      final total = othersText.length + chants.length;
      // After the rows: the next page loading, or the library's error
      // with Retry (a first page that failed while space chants show, or
      // a later page, which never pages on scroll again).
      final Widget? tail =
          state.isLoadingMore
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
              : state.error != null
              ? ChantLoadNotice(
                message: state.error!,
                padding: EdgeInsets.zero,
                onRetry:
                    () =>
                        chants.isEmpty
                            ? ref.read(provider.notifier).retry()
                            : ref.read(provider.notifier).loadMore(),
              )
              : null;
      list = _rows(
        itemCount: lead + total + (tail == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (index < lead) return spacesNotice!;
          final i = index - lead;
          if (i == total) return tail!;
          if (i < othersText.length) {
            return SpaceTextChantRow(chant: othersText[i]);
          }
          final chant = chants[i - othersText.length];
          return TextChantRow(
            title: chant.title,
            openLabel: l10n.chants_open_chant,
            language: chant.language,
            firstVerse: chant.firstSegment?.content,
            onTap:
                () => openRecitationReader(
                  context,
                  chant,
                  listLanguage: languageCode,
                ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppAssets.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.chants_text_only,
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
          if (hasYours)
            ChantFilterPills(
              labels: [l10n.chants_your_spaces, l10n.chants_other_spaces],
              selectedIndex: showYours ? 0 : 1,
              onSelected: (i) {
                setState(() => _showYours = i == 0);
                if (_scrollController.hasClients) _scrollController.jumpTo(0);
              },
            ),
          Expanded(child: RefreshIndicator(onRefresh: _refresh, child: list)),
        ],
      ),
      floatingActionButton:
          _isCreateFlowOpen
              ? null
              : ChantBookCreateButton(
                label: l10n.chants_create_chant_book,
                onPressed: _create,
              ),
    );
  }

  /// An empty list that still pulls to refresh, with [notice] above the
  /// message when part of the chants could not be read.
  Widget _empty(String message, {Widget? notice}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        if (notice != null) notice,
        const SizedBox(height: 120),
        Center(child: Text(message)),
      ],
    );
  }

  /// The list both pills use: rows 8pt apart, room under the last one for
  /// the Chant book button.
  Widget _rows({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: itemCount,
      itemBuilder:
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: itemBuilder(context, index),
          ),
    );
  }
}
