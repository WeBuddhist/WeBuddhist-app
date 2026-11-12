import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/localization/content_language_picker_sheet.dart';
import 'package:flutter_pecha/core/widgets/error_state_widget.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_actions.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_book_card.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_filter_pills.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_section_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which chant books a See-all grid lists.
enum ChantBooksSeeAll {
  /// The user's own and imported books, paged.
  mine,

  /// Space books with a Your spaces / Other spaces toggle, opened on yours.
  yourSpaces,

  /// Space books with the toggle, opened on other spaces.
  otherSpaces,
}

/// See all for chant books: a two-column grid of [ChantBookCard]s.
class ChantBooksSeeAllScreen extends ConsumerStatefulWidget {
  const ChantBooksSeeAllScreen({super.key, required this.list});

  final ChantBooksSeeAll list;

  @override
  ConsumerState<ChantBooksSeeAllScreen> createState() =>
      _ChantBooksSeeAllScreenState();
}

class _ChantBooksSeeAllScreenState
    extends ConsumerState<ChantBooksSeeAllScreen> {
  final ScrollController _scrollController = ScrollController();
  late bool _showYours = widget.list != ChantBooksSeeAll.otherSpaces;
  bool _isCreateFlowOpen = false;

  bool get _isMine => widget.list == ChantBooksSeeAll.mine;

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

  void _onScroll() {
    if (!_isMine) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(myChantBooksPagedProvider.notifier).loadMore();
    }
  }

  /// The chant list language, shared with the Chants page, as in the design.
  void _openLanguagePicker() {
    showContentLanguagePickerSheet(
      context,
      selectedCode: ref.read(practiceRecitationsLanguageProvider),
      recitationOnly: true,
      onSelected:
          (code) => ref
              .read(practiceRecitationsLanguageProvider.notifier)
              .setLanguage(code),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppAssets.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isMine ? l10n.chants_my_chant_books : l10n.chants_chant_books,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          strutStyle: context.tibetanStrutStyle(20),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(AppAssets.language),
            tooltip: l10n.language,
            onPressed: _openLanguagePicker,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isMine ? _buildMine(context) : _buildSpaces(context),
      floatingActionButton:
          _isCreateFlowOpen
              ? null
              : ChantBookCreateButton(
                label: l10n.chants_create_chant_book,
                onPressed: _create,
              ),
    );
  }

  Widget _buildMine(BuildContext context) {
    final state = ref.watch(myChantBooksPagedProvider);
    final notifier = ref.read(myChantBooksPagedProvider.notifier);
    if (state.isLoading && state.books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.books.isEmpty) {
      return ErrorStateWidget(
        error: state.error!.message,
        onRetry: notifier.loadInitial,
      );
    }
    if (state.books.isEmpty) {
      return Center(child: Text(context.l10n.noContentAvailable));
    }
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: _ChantBookGrid(
        books: state.books,
        controller: _scrollController,
        isLoadingMore: state.isLoadingMore,
        onTap: (book) => openChantBook(context, ref, book),
      ),
    );
  }

  Widget _buildSpaces(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(spaceChantBooksProvider);
    final result = async.valueOrNull;
    if (result == null) {
      if (async.hasError) {
        return ErrorStateWidget(
          error: async.error.toString(),
          onRetry: () => ref.invalidate(spaceChantBooksProvider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return result.fold(
      (failure) => ErrorStateWidget(
        error: failure.message,
        onRetry: () => ref.invalidate(spaceChantBooksProvider),
      ),
      (spaces) {
        // No books in the user's spaces: no toggle, other spaces only.
        final hasYours = spaces.hasYourSpaces;
        final showYours = hasYours && _showYours;
        final books = showYours ? spaces.yours : spaces.others;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasYours)
              ChantFilterPills(
                labels: [
                  l10n.chants_your_spaces,
                  l10n.chants_other_spaces,
                ],
                selectedIndex: showYours ? 0 : 1,
                onSelected: (i) {
                  setState(() => _showYours = i == 0);
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(0);
                  }
                },
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(spaceChantBooksProvider.future),
                child:
                    books.isEmpty
                        ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            Center(child: Text(l10n.noContentAvailable)),
                          ],
                        )
                        : _ChantBookGrid(
                          books: books,
                          controller: _scrollController,
                          onTap: (book) => openChantBook(context, ref, book),
                        ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Two columns of chant book cards sized to the screen width.
class _ChantBookGrid extends StatelessWidget {
  const _ChantBookGrid({
    required this.books,
    required this.controller,
    required this.onTap,
    this.isLoadingMore = false,
  });

  final List<ChantBook> books;
  final ScrollController controller;
  final ValueChanged<ChantBook> onTap;
  final bool isLoadingMore;

  static const double _gutter = 20;
  static const double _gap = 10;

  /// Gap, a Tibetan-height title, gap and the subtitle under each cover.
  static const double _textHeight = 8 + 29 + 2 + 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - _gutter * 2 - _gap) / 2;
        return CustomScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: _gap,
                  // The text height already leaves room for a Tibetan
                  // title, so Latin rows get the design's ~15pt gap.
                  mainAxisSpacing: 4,
                  mainAxisExtent: cell + _textHeight,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final book = books[index];
                  return Align(
                    alignment: Alignment.topLeft,
                    child: ChantBookCard(
                      name: book.name,
                      chantCount: book.chantCount,
                      subtitle: book.subtitle,
                      imageUrl: book.imageUrl ?? book.groupAvatarUrl,
                      hasAudio: book.hasAudio,
                      width: cell,
                      onTap: () => onTap(book),
                    ),
                  );
                }, childCount: books.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                // Room under the last row for the Chant book button.
                padding: const EdgeInsets.only(top: 16, bottom: 96),
                child:
                    isLoadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}
