import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/localization/content_language_picker_sheet.dart';
import 'package:flutter_pecha/core/widgets/error_state_widget.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_recitations_paginated_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/recitations_search_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/chants_page_actions.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_filter_pills.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_load_notice.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_section_header.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/space_chant_rows.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// See all for chants with audio, with the Your spaces / Other spaces
/// pills. A user with no audio chants in their spaces gets other spaces
/// only, with no pills.
class AudioChantsSeeAllScreen extends ConsumerStatefulWidget {
  const AudioChantsSeeAllScreen({super.key, this.showYours = true});

  /// Opens on the user's spaces; false opens on other spaces.
  final bool showYours;

  @override
  ConsumerState<AudioChantsSeeAllScreen> createState() =>
      _AudioChantsSeeAllScreenState();
}

class _AudioChantsSeeAllScreenState
    extends ConsumerState<AudioChantsSeeAllScreen> {
  final ScrollController _scrollController = ScrollController();
  late bool _showYours = widget.showYours;
  bool _isCreateFlowOpen = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final async = ref.watch(spaceChantsProvider);
    final chants = async.valueOrNull?.fold((_) => null, (c) => c);
    // The pills follow the chants in every language, so a language with
    // none in the user's spaces empties the list but keeps the pills.
    final hasYours =
        ref
            .watch(allSpaceChantsProvider)
            .valueOrNull
            ?.fold((_) => null, (all) => all.yoursAudio.isNotEmpty) ??
        _showYours;
    // Titled as on the Chants page: "Audio chants" for a user whose spaces
    // have no chant books.
    final isNewUser =
        ref
            .watch(spaceChantBooksProvider)
            .valueOrNull
            ?.fold((_) => null, (books) => !books.hasYourSpaces) ??
        false;

    final Widget body;
    if (chants == null) {
      final failure = async.valueOrNull?.fold((f) => f, (_) => null);
      if (failure != null || async.hasError) {
        body = ErrorStateWidget(
          error: failure?.message ?? async.error.toString(),
          onRetry: () => ref.invalidate(spaceChantBooksProvider),
        );
      } else {
        body = const Center(child: CircularProgressIndicator());
      }
    } else {
      final showYours = hasYours && _showYours;
      final list = showYours ? chants.yoursAudio : chants.othersAudio;
      // Some chant books could not be read: said above the list.
      final notice =
          chants.isPartial
              ? ChantLoadNotice(
                message: l10n.unableToLoad,
                onRetry: () => ref.invalidate(spaceChantBooksProvider),
                padding: const EdgeInsets.only(bottom: 4),
              )
              : null;
      final lead = notice == null ? 0 : 1;
      body = Column(
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(spaceChantBooksProvider);
                await ref.read(spaceChantsProvider.future);
              },
              child:
                  list.isEmpty
                      ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                        children: [
                          if (notice != null) notice,
                          const SizedBox(height: 120),
                          Center(child: Text(l10n.noContentAvailable)),
                        ],
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        // Room under the last row for the Chant book button.
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                        itemCount: list.length + lead,
                        itemBuilder:
                            (context, index) =>
                                index < lead
                                    ? notice!
                                    : Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: SpaceAudioChantRow(
                                        chant: list[index - lead],
                                      ),
                                    ),
                      ),
            ),
          ),
        ],
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
          isNewUser ? l10n.chants_audio_chants : l10n.chants_with_audio,
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
      body: body,
      floatingActionButton:
          _isCreateFlowOpen
              ? null
              : ChantBookCreateButton(
                label: l10n.chants_create_chant_book,
                onPressed: _create,
              ),
    );
  }
}
