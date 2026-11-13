import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_actions.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_sections.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/recitation_reader_navigation.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_book_card.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_filter_pills.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_rows.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_section_header.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/space_chant_rows.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_pecha/features/recitation/presentation/providers/recitation_search_provider.dart';
import 'package:flutter_pecha/features/recitation/presentation/widgets/recitation_list_skeleton.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either;

/// Search on the Chants page: results grouped into chant books, text-only
/// chants and audio chants, with All / Chant books / Audio chants / Single
/// chants pills. Space chants are matched against the already-loaded
/// space chant books; library chants are searched on the server.
/// "Request text" sends the query to the team (`POST /text-requests`).
class RecitationsSearchScreen extends ConsumerStatefulWidget {
  const RecitationsSearchScreen({super.key, required this.languageCode});

  final String languageCode;

  @override
  ConsumerState<RecitationsSearchScreen> createState() =>
      _RecitationsSearchScreenState();
}

class _RecitationsSearchScreenState
    extends ConsumerState<RecitationsSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  _SearchFilter _filter = _SearchFilter.all;

  /// The chant book and space chant query, set after the same pause as the
  /// chant search.
  String _bookQuery = '';
  Timer? _bookDebounce;

  /// "Request text" while it is being sent, and the last query sent (lower
  /// case), so the same search is not requested twice.
  bool _sendingRequest = false;
  String? _requestedQuery;

  RecitationSearchNotifier get _searchNotifier =>
      ref.read(practiceRecitationSearchProvider(widget.languageCode).notifier);

  @override
  void initState() {
    super.initState();
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
    _bookDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _focusNode.dispose();
    // No clear() here: `ref` cannot be used in dispose, and the search
    // provider is autoDispose, so its results are dropped once this screen
    // stops watching it.
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _searchNotifier.search(query);
    _bookDebounce?.cancel();
    _bookDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _bookQuery = query.trim());
    });
  }

  void _onClear() {
    _searchController.clear();
    _searchNotifier.clear();
    _bookDebounce?.cancel();
    setState(() => _bookQuery = '');
    _focusNode.requestFocus();
  }

  void _onBack() {
    _searchNotifier.clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.grey300;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final hasQuery =
        _searchController.text.trim().length >= chantsSearchMinQueryLength;
    // Watched even before a query, so the autoDispose search notifier the
    // field writes to stays alive between keystrokes.
    final chantState = ref.watch(
      practiceRecitationSearchProvider(widget.languageCode),
    );
    final spaceMatches = _spaceMatches();
    // The design shows the pills over results only, not over "Can't find".
    final hasResults =
        chantState.results.isNotEmpty ||
        spaceMatches.audio.isNotEmpty ||
        spaceMatches.text.isNotEmpty ||
        (ref
                .watch(chantBookSearchProvider(_bookQuery))
                .valueOrNull
                ?.fold((_) => false, (books) => books.isNotEmpty) ??
            false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onBack,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(AppAssets.arrowLeft),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: l10n.chants_search_hint,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          AppAssets.search,
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
                                      ).clearButtonTooltip,
                                  icon: Icon(
                                    AppAssets.x,
                                    size: 20,
                                    color: subtitleColor,
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
            if (hasQuery && hasResults)
              ChantFilterPills(
                labels: [
                  l10n.chants_filter_all,
                  l10n.chants_chant_books,
                  l10n.chants_audio_chants,
                  l10n.chants_filter_single_chants,
                ],
                selectedIndex: _filter.index,
                onSelected:
                    (i) => setState(() => _filter = _SearchFilter.values[i]),
              ),
            Expanded(
              child:
                  hasQuery
                      ? _buildResults(context, chantState, spaceMatches)
                      : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  /// Space chants matching the settled query; none until it is long enough.
  ({List<SpaceChant> audio, List<SpaceChant> text}) _spaceMatches() {
    final chants = ref
        .watch(spaceChantsProvider)
        .valueOrNull
        ?.fold((_) => null, (c) => c);
    if (chants == null || _bookQuery.length < chantsSearchMinQueryLength) {
      return (audio: const [], text: const []);
    }
    return matchSpaceChants(chants, _bookQuery);
  }

  Widget _buildResults(
    BuildContext context,
    RecitationSearchState chantState,
    ({List<SpaceChant> audio, List<SpaceChant> text}) spaceMatches,
  ) {
    final l10n = context.l10n;
    final bookAsync = ref.watch(chantBookSearchProvider(_bookQuery));
    final books =
        bookAsync.valueOrNull?.fold((_) => const <ChantBook>[], (b) => b) ??
        const <ChantBook>[];
    final chants = chantState.results;

    final wantsBooks = _filter.shows(_SearchFilter.chantBooks);
    final wantsText = _filter.shows(_SearchFilter.singleChants);
    final wantsAudio = _filter.shows(_SearchFilter.audioChants);
    final showBooks = wantsBooks && books.isNotEmpty;
    final showText =
        wantsText && (chants.isNotEmpty || spaceMatches.text.isNotEmpty);
    final showAudio = wantsAudio && spaceMatches.audio.isNotEmpty;
    final queryPending = _bookQuery != _searchController.text.trim();
    final spacesPending =
        (wantsText || wantsAudio) &&
        (queryPending || ref.watch(spaceChantsProvider).isLoading);
    final booksPending = wantsBooks && (bookAsync.isLoading || queryPending);
    final chantsPending = wantsText && chantState.isLoading;

    if (!showBooks && !showText && !showAudio) {
      if (booksPending || chantsPending || spacesPending) {
        return const RecitationListSkeleton(
          variant: RecitationListSkeletonVariant.chantTile,
        );
      }
      // Nothing to show: a source that failed may have held the match, so
      // offer a retry of every failed source rather than "Can't find".
      final chantError = wantsText ? chantState.error : null;
      final bookError = wantsBooks ? _failureMessage(bookAsync) : null;
      final spaceError =
          wantsText || wantsAudio
              ? _failureMessage(ref.watch(spaceChantsProvider))
              : null;
      final error = chantError ?? bookError ?? spaceError;
      if (error != null) {
        return _SearchError(
          message: error,
          onRetry: () {
            if (chantError != null) _searchNotifier.retry();
            // The book search reads the space books too, so this
            // re-runs it as well.
            if (spaceError != null) ref.invalidate(spaceChantBooksProvider);
            if (bookError != null) {
              ref.invalidate(chantBookSearchProvider(_bookQuery));
            }
          },
        );
      }
      return _CantFind(
        centered: true,
        status: _requestStatus,
        onRequestText: _requestText,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        if (showBooks) ...[
          ChantSectionHeader(title: l10n.chants_chant_books),
          _BookRail(
            books: books,
            onTap: (book) => openChantBook(context, ref, book),
          ),
        ],
        if (showText) ...[
          ChantSectionHeader(title: l10n.chants_text_only),
          for (final chant in spaceMatches.text)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SpaceTextChantRow(chant: chant),
            ),
          for (final chant in chants) _chantRow(context, chant),
        ],
        if (showAudio) ...[
          ChantSectionHeader(title: l10n.chants_audio_chants),
          for (final chant in spaceMatches.audio)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SpaceAudioChantRow(chant: chant),
            ),
        ],
        const SizedBox(height: 16),
        _CantFind(
          centered: false,
          status: _requestStatus,
          onRequestText: _requestText,
        ),
      ],
    );
  }

  /// The message of a failed load, whether it threw or returned a failure;
  /// null while loading or when it succeeded.
  static String? _failureMessage<T>(AsyncValue<Either<Failure, T>> async) {
    if (async.isLoading) return null;
    if (async.hasError) return async.error.toString();
    return async.valueOrNull?.fold((failure) => failure.message, (_) => null);
  }

  _RequestStatus get _requestStatus {
    if (_sendingRequest) return _RequestStatus.sending;
    final query = _searchController.text.trim().toLowerCase();
    return query == _requestedQuery ? _RequestStatus.sent : _RequestStatus.idle;
  }

  /// Sends the current query as a text request. Guests and expired sessions
  /// get the login drawer: the endpoint needs a signed-in user.
  Future<void> _requestText() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _requestStatus != _RequestStatus.idle) return;
    final auth = ref.read(authProvider);
    if (auth.isGuest || !auth.isLoggedIn) {
      LoginDrawer.show(context, ref);
      return;
    }

    setState(() => _sendingRequest = true);
    final result = await ref
        .read(chantsPageRepositoryProvider)
        .requestText(query: query, language: widget.languageCode);
    if (!mounted) return;
    final l10n = context.l10n;
    setState(() {
      _sendingRequest = false;
      if (result.isRight()) _requestedQuery = query.toLowerCase();
    });
    context.showSnackBar(
      result.fold(
        (failure) =>
            failure is RateLimitFailure
                ? l10n.chants_request_limit
                : l10n.something_went_wrong,
        (_) => l10n.chants_request_sent,
      ),
    );
  }

  Widget _chantRow(BuildContext context, RecitationModel chant) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: TextChantRow(
        title: chant.title,
        openLabel: context.l10n.chants_open_chant,
        language: chant.language,
        firstVerse: chant.firstSegment?.content,
        onTap:
            () => openRecitationReader(
              context,
              chant,
              listLanguage: widget.languageCode,
            ),
      ),
    );
  }
}

class _BookRail extends StatelessWidget {
  const _BookRail({required this.books, required this.onTap});

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

/// The search pills, in the design's order.
enum _SearchFilter {
  all,
  chantBooks,
  audioChants,
  singleChants;

  /// Whether this pill shows [section]'s results.
  bool shows(_SearchFilter section) => this == all || this == section;
}

enum _RequestStatus { idle, sending, sent }

/// "Can't find the text you're looking for?" with a Request text button:
/// centred with an icon when nothing matched, a quiet footer under results
/// otherwise. The button shows a spinner while sending and "Requested" once
/// this query was sent.
class _CantFind extends StatelessWidget {
  const _CantFind({
    required this.centered,
    required this.status,
    required this.onRequestText,
  });

  final bool centered;
  final _RequestStatus status;
  final VoidCallback onRequestText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final muted = isDark ? AppColors.textTertiaryDark : AppColors.textSecondary;

    final Widget icon = switch (status) {
      _RequestStatus.idle => Icon(AppAssets.requestText, size: 20, color: ink),
      _RequestStatus.sending => SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: muted),
      ),
      _RequestStatus.sent => Icon(AppAssets.check, size: 18, color: muted),
    };
    final button = OutlinedButton.icon(
      onPressed: status == _RequestStatus.idle ? onRequestText : null,
      icon: icon,
      label: Text(
        status == _RequestStatus.sent
            ? l10n.chants_request_done
            : l10n.chants_request_text,
        style: TextStyle(
          fontSize: 14,
          color: status == _RequestStatus.idle ? ink : muted,
        ),
      ),
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        backgroundColor:
            isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
        side: BorderSide(
          color: isDark ? AppColors.cardBorderDark : AppColors.grey300,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
    );

    if (!centered) {
      return Column(
        children: [
          Text(
            l10n.chants_cant_find,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 10),
          button,
        ],
      );
    }

    return Align(
      alignment: const Alignment(0, -0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.surfaceDark : AppColors.grey100,
              ),
              alignment: Alignment.center,
              child: Icon(AppAssets.search, size: 28, color: muted),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.chants_cant_find,
              textAlign: TextAlign.center,
              strutStyle: context.tibetanStrutStyle(17),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 20),
            button,
          ],
        ),
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}
