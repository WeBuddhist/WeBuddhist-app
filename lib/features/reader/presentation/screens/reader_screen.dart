import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/analytics/media_analytics.dart';
import 'package:flutter_pecha/core/config/router/app_router.dart';
import 'package:flutter_pecha/core/config/router/app_routes.dart';
import 'package:flutter_pecha/core/error/load_error_kind.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/core/widgets/slide_away_header.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/prayer_requests_button.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_accumulator_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/add_offline_chants_dialog.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_accumulator_chant_bar.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_accumulator_chant_footer.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_recitation_audio_sheet.dart';
import 'package:flutter_pecha/features/library/data/repositories/library_repository.dart';
import 'package:flutter_pecha/features/library/presentation/providers/library_providers.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_accumulation_selection.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/accumulation_chant_counter.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/accumulator_groups_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/group_accumulation_counts_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_accumulation_selection_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_sync_manager.dart';
import 'package:flutter_pecha/features/plans/presentation/providers/plan_days_providers.dart';
import 'package:flutter_pecha/features/plans/presentation/providers/user_plans_provider.dart';
import 'package:flutter_pecha/features/plans/presentation/utils/plan_live_pill.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_audio_button.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_audio_player_bar.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_task_live_badge.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_embedded_host.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_navigator.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_segment_audio_controller.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_subtask_completion.dart';
import 'package:flutter_pecha/features/practice/data/datasource/bookmark_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/bookmark_providers.dart';
import 'package:flutter_pecha/features/reader/constants/reader_constants.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_pecha/features/reader/presentation/style/reader_style.dart';
import 'package:flutter_pecha/features/reader/data/models/reader_slot_config.dart';
import 'package:flutter_pecha/features/reader/data/models/reader_state.dart';
import 'package:flutter_pecha/features/reader/domain/services/live_position_resolver.dart';
import 'package:flutter_pecha/features/reader/domain/services/navigation_service.dart';
import 'package:flutter_pecha/features/reader/presentation/providers/reader_dual_settings_provider.dart';
import 'package:flutter_pecha/features/reader/presentation/providers/reader_notifier.dart';
import 'package:flutter_pecha/features/reader/presentation/utils/chant_recordings_loader.dart';
import 'package:flutter_pecha/features/reader/presentation/utils/deferred_recitation.dart';
import 'package:flutter_pecha/features/reader/presentation/utils/reader_transliteration.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_actions/reader_verse_sheet.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_app_bar/reader_app_bar.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_app_bar/reader_font_size_bottom_sheet.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_app_bar/reader_font_size_button.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_app_bar/reader_languages_button.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_app_bar/reader_more_bottom_sheet.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_content/reader_content_part.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_gestures/swipe_navigation_wrapper.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_search/reader_search_delegate.dart';
import 'package:flutter_pecha/features/reader/presentation/widgets/reader_settings/reader_languages_sheet.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/utils/get_language.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_live_position.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_pecha/features/recitation/presentation/providers/recitation_live_notifier.dart';
import 'package:flutter_pecha/features/recitation/presentation/widgets/recitation_live_sync_toggle.dart';
import 'package:flutter_pecha/features/texts/data/models/text_detail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

/// Player for a library chant recording. It has no fixed URL: the
/// presigned link is fetched on play and again after a player error.
@visibleForTesting
PlanSegmentAudioController chantRecordingAudioController(
  LibraryRepository repository,
  ChantAudioTrack track, {
  AudioPlayer Function()? createPlayer,
  void Function(PlanAudioListen listen)? onListened,
}) {
  return PlanSegmentAudioController(
    url: null,
    startMs: 0,
    endMs: null,
    onSegmentComplete: () {},
    onListened: onListened,
    resolveUrl: () => repository.getRecordingAudioUrl(track.id),
    createPlayer: createPlayer,
  );
}

/// Main reader screen - thin orchestrator that composes child widgets
class ReaderScreen extends ConsumerStatefulWidget {
  final String textId;
  final String? segmentId;
  final NavigationContext? navigationContext;
  final int? colorIndex;

  const ReaderScreen({
    super.key,
    required this.textId,
    this.segmentId,
    this.navigationContext,
    this.colorIndex,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin {
  /// One reader per text on this page: the text opened, or each source of
  /// the plan task. The first gates loading and errors.
  late List<ReaderParams> _sources;
  late ReaderParams _params;

  /// The source whose segment was last tapped: its selection, panels and
  /// sheets are the ones on screen.
  late ReaderParams _activeParams;

  /// Gap kept below the floating audio button when it sits over the bare
  /// reader content (no action bar). Matches the original floating offset.
  static const double _audioBottomGap = 76;

  /// Space between the round play button and the audio bar.
  static const double _playBarGap = 12;

  /// Lets the audio button keep its state when it is reparented between the
  /// behind-panel slot and the bottom overlay.
  final GlobalKey _audioButtonKey = GlobalKey();
  static const double _defaultContentBottomPadding = 60;
  static const double _selectedSegmentOverlayFallbackHeight = 360;

  // App bar visibility state
  bool _isAppBarVisible = true;

  /// How far through the page the reader is, for the header's progress line.
  final ValueNotifier<double> _progress = ValueNotifier(0);
  double _bottomOverlayHeight = 0;

  /// Height of the navigation strip plus the audio controls sitting on it.
  double _bottomBarHeight = 0;
  VoidCallback? _scrollToTop;

  // Group accumulation chant session
  bool _chantSessionFinished = false;

  /// Chants made in this visit, whichever target each one was counted into.
  int _chantSessionCount = 0;

  /// A recitation from Recite again, shown as counted but held back while
  /// its toast offers Undo. Counted when the window closes, or sooner when
  /// the visit moves on (another count, finishing, leaving).
  late final _pendingRecitation = DeferredRecitation(
    window: _undoWindow,
    onCommit: _onPendingRecitationCommitted,
  );

  /// Where the pending recitation goes: the target selected when Recite
  /// again was tapped (a joined accumulation's id, or null for personal
  /// practice), not whatever is selected once the Undo window closes.
  String? _pendingTarget;

  /// True from [dispose] on, where a pending recitation is counted through
  /// [_container] since `ref` can no longer be used.
  bool _disposing = false;

  /// Set once Finish and count has counted the recitation on screen. It is
  /// then in [_recitationsCounted] already, so the footer stops adding it,
  /// and a retry after finishing threw does not count it twice.
  bool _finishedRecitationCounted = false;

  /// True from a finish action until the session is finished, or finishing
  /// threw. Every chant action is off meanwhile, so a slow sync cannot let
  /// Recite again hold the recitation Finish and count already counted.
  bool _isFinishing = false;

  /// How long Recite again's toast offers Undo.
  static const _undoWindow = Duration(seconds: 5);

  /// Held for counting a pending recitation from [dispose], where `ref` and
  /// context lookups are no longer allowed.
  ProviderContainer? _container;

  /// Recitations counted in this visit, the one waiting on Undo included.
  int get _recitationsCounted =>
      _chantSessionCount + (_pendingRecitation.isPending ? 1 : 0);

  /// Those counted into the accumulation this reader was opened from, which
  /// is what its completion sheet reports.
  int _chantOpenedCount = 0;

  /// True once the accumulation this reader was opened from is the selected
  /// target; until then the selection still holds its unloaded default.
  bool _chantSelectionReady = false;

  NavigationContext? get _chantContext {
    final ctx = widget.navigationContext;
    if (ctx == null || !ctx.isGroupAccumulatorChant) return null;
    return ctx;
  }

  bool get _isGroupAccumulatorChant => _chantContext != null;

  bool get _openedEndedAccumulator =>
      _chantContext?.groupAccumulatorEnded == true;

  /// The chant's preset as the key its counters are held under. A recitation
  /// is not in the mala catalogue, so there is no fuller [Mantra] to use.
  Mantra? get _chantMantra {
    final presetId = _chantContext?.presetAccumulatorId;
    return presetId == null ? null : Mantra(presetId: presetId);
  }

  /// Set when the reader was opened from a group event.
  String? get _eventId {
    final ctx = widget.navigationContext;
    return ctx != null && ctx.isFromEvent ? ctx.eventId : null;
  }

  /// Set when the reader follows a group event's live recitation.
  String? get _liveEventId {
    final ctx = widget.navigationContext;
    return ctx != null && ctx.isLiveRecitation ? ctx.eventId : null;
  }

  bool get _isEmbedded => PlanEmbeddedScope.maybeOf(context) != null;

  // ─── Audio ─────────────────────────────────────────────────────────────
  // Plays the current SOURCE_REFERENCE subtask's audio when the reader is
  // opened from a plan, and the library's recordings of a chant. Shares the
  // engine with PlanTextScreen.
  PlanSegmentAudioController? _audioController;
  bool _isAdvancing = false;
  static final _logger = AppLogger('ReaderScreen');

  /// Loads the library recordings of the chant on screen. Null for plans
  /// and the library reader, which never play them.
  ChantRecordingsLoader? _chantRecordings;

  /// The last load failed and nothing has loaded since: the play spot offers
  /// a retry instead of hiding, so a passing error is not read as no audio.
  bool _chantRecordingsFailed = false;

  /// Recordings of the chant on screen, titled in the UI language; empty
  /// until they load.
  List<ChantAudioTrack> get _chantTracks {
    final recordings = _chantRecordings?.recordings ?? const [];
    if (recordings.isEmpty) return const [];
    return ChantAudioTrack.fromRecordings(
      recordings,
      Localizations.localeOf(context).languageCode,
    );
  }

  bool get _showsChantRetry => _chantRecordingsFailed && _chantTracks.isEmpty;

  /// Recording chosen from Audio versions on this screen. Null means the
  /// first recording of the chant on screen.
  ChantAudioTrack? _selectedCollectionTrack;

  bool get _hasCollectionAudioChoices => _chantTracks.isNotEmpty;

  bool get _hasAudio =>
      (_audioController?.hasAudio ?? false) ||
      _hasCollectionAudioChoices ||
      _showsChantRetry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _sources = _sourceParams();
    _params = _sources.first;
    _activeParams = _params;
    _initAudio();
    _initGroupAccumulatorChantSession();
  }

  /// A reader per source text of the plan task opened, else one for the
  /// text opened, restricted to the task's verses when it names them.
  List<ReaderParams> _sourceParams() {
    final ctx = widget.navigationContext;
    final item = ctx?.currentItem;
    if (item == null ||
        !item.isSourceReference ||
        item.textId != widget.textId) {
      return [
        ReaderParams(
          textId: widget.textId,
          segmentId: widget.segmentId,
          navigationContext: ctx,
        ),
      ];
    }
    return [
      for (final (index, source) in item.sources.indexed)
        ReaderParams(
          textId: source.textId,
          segmentId: index == 0
              ? widget.segmentId ?? source.firstSegmentId
              : source.firstSegmentId,
          segmentIds: source.segmentIds,
          navigationContext: ctx,
          sourceLanguage: source.language,
        ),
    ];
  }

  void _onSourceSelected(ReaderParams params) {
    if (_activeParams == params) return;
    setState(() => _activeParams = params);
  }

  /// Drops the selection and open panels; only the active source has any.
  void _clearTransientState() {
    final notifier = ref.read(readerNotifierProvider(_activeParams).notifier);
    notifier.selectSegment(null);
    notifier.closeCommentary();
    notifier.closeTranslation();
  }

  void _initGroupAccumulatorChantSession() {
    final ctx = _chantContext;
    if (ctx == null) return;

    final presetId = ctx.presetAccumulatorId!;
    final groupAccumulatorId = ctx.groupAccumulatorId!;
    final sessionCount = ctx.groupAccumulatorSessionCount ?? 0;

    Future.microtask(() async {
      if (!mounted) return;
      final selection = ref.read(
        malaAccumulationSelectionProvider(presetId).notifier,
      );
      await selection.applyNavigationIntent(groupAccumulatorId);
      // Chants go to the selected target, so the opened accumulation has to
      // be selected before the first one is counted.
      await selection.loaded;
      if (!mounted) return;
      final countsNotifier = ref.read(
        groupAccumulationCountsProvider(presetId).notifier,
      );
      await countsNotifier.mergeFromServerCounts({
        groupAccumulatorId: sessionCount,
      });
      if (!mounted) return;
      setState(() => _chantSelectionReady = true);
    });
  }

  /// Counts one chant into the target selected in the accumulation sheet.
  void _countChant() {
    final mantra = _chantMantra;
    if (mantra == null) return;
    _countChantInto(chantTargetOf(ref.read, mantra));
  }

  /// Counts one chant into [groupAccumulatorId], or personal practice when
  /// null, whatever is selected now.
  void _countChantInto(String? groupAccumulatorId) {
    if (_openedEndedAccumulator) return;
    final mantra = _chantMantra;
    if (mantra == null) return;

    final counted = countChantInto(
      ref.read,
      mantra,
      groupAccumulatorId: groupAccumulatorId,
    );
    if (!counted) return;
    final opened = _chantContext?.groupAccumulatorId;
    _tallyChantsInto(
      1,
      intoOpened: opened != null && opened == groupAccumulatorId,
    );
  }

  /// Adds chants just counted into the selected target to this visit's tallies.
  void _tallyChants(Mantra mantra, int count) {
    final opened = _chantContext?.groupAccumulatorId;
    _tallyChantsInto(
      count,
      intoOpened: opened != null && isChantTarget(ref.read, mantra, opened),
    );
  }

  /// Adds chants just counted to this visit's tallies; [intoOpened] when they
  /// went to the accumulation this reader was opened from.
  void _tallyChantsInto(int count, {required bool intoOpened}) {
    setState(() {
      _chantSessionCount += count;
      if (intoOpened) _chantOpenedCount += count;
    });
  }

  /// False while the selected target cannot take a chant yet: the selection is
  /// still loading, personal practice was just picked and is seeding, or a
  /// group was picked whose session count has not come from the server. The
  /// personal counter is only created once it is the target.
  bool _watchChantTargetReady(Mantra mantra) {
    if (!_chantSelectionReady) return false;
    final presetId = mantra.presetId;
    final selection = ref.watch(malaAccumulationSelectionProvider(presetId));
    final groupAccumulatorId = selection.groupAccumulatorId;
    if (groupAccumulatorId != null) {
      ref.watch(groupAccumulationCountsProvider(presetId));
      return ref
          .read(groupAccumulationCountsProvider(presetId).notifier)
          .hasServerCount(groupAccumulatorId);
    }
    return !ref.watch(malaCounterProvider(mantra)).isSeeding;
  }

  /// Counts the recitation just finished, after an Undo window, and goes
  /// back to the opening verse for the next one.
  void _onReciteAgain() {
    if (_isFinishing) return;
    final mantra = _chantMantra;
    if (mantra == null) return;
    _scrollToTop?.call();
    if (_finishedRecitationCounted) {
      // Finishing threw after counting this recitation: start the next pass
      // without counting it again.
      setState(() => _finishedRecitationCounted = false);
      return;
    }
    // Counts the one already held, into its own target, before taking this.
    _pendingRecitation.hold();
    _pendingTarget = chantTargetOf(ref.read, mantra);
    setState(() {});
    _showRecitationCountedToast();
  }

  void _showRecitationCountedToast() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // A SnackBar with an action stays up past its duration unless told
          // not to; this one has to go when the Undo window closes.
          persist: false,
          behavior: SnackBarBehavior.floating,
          // Figma: floats just above the chant bar.
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            GroupAccumulatorChantBar.barHeight + 8,
          ),
          duration: _undoWindow,
          content: Text(
            l10n.group_accumulator_recitations_counted(_recitationsCounted),
          ),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: _undoPendingRecitation,
          ),
        ),
      );
  }

  /// Drops the recitation waiting on Undo; nothing reached the counters.
  void _undoPendingRecitation() {
    if (!mounted) return;
    if (_pendingRecitation.undo()) setState(() {});
  }

  /// Counts the recitation waiting on Undo, if there is one; committing takes
  /// its toast away so no Undo is left offered for it.
  void _settlePendingRecitation() {
    if (!_pendingRecitation.isPending) return;
    _pendingRecitation.commit();
  }

  void _onPendingRecitationCommitted() {
    final mantra = _chantMantra;
    if (mantra == null) return;
    final target = _pendingTarget;
    if (_disposing) {
      // The counters are held open by this widget until after dispose, so
      // the container can still reach them.
      final container = _container;
      if (container != null) {
        countChantInto(container.read, mantra, groupAccumulatorId: target);
      }
      return;
    }
    if (!mounted) return;
    // The toast's own timer starts after its entrance animation, so it can
    // outlast the Undo window briefly; take it down with the count.
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    // Redraws even when the target turns the count away.
    setState(() {});
    _countChantInto(target);
  }

  /// A different target was picked while a recitation waits on Undo: count
  /// it now, into the target it was made for. Waiting would let the old
  /// target's counter go (personal practice is only held while selected).
  void _onChantSelectionChanged(
    MalaAccumulationSelection? previous,
    MalaAccumulationSelection next,
  ) {
    if (!_pendingRecitation.isPending) return;
    if (next.groupAccumulatorId == _pendingTarget) return;
    _settlePendingRecitation();
  }

  /// Counts the recitation just finished and ends the session.
  Future<void> _finishAndCount() => _finishing(() {
    if (!_finishedRecitationCounted) {
      _finishedRecitationCounted = true;
      _countChant();
    }
  });

  /// Ends the session without counting the recitation just finished. One
  /// already shown as counted by Recite again still counts.
  Future<void> _finishWithoutCounting() => _finishing(() {});

  /// Locks the chant actions, settles any recitation waiting on Undo, runs
  /// [countFinished], then finishes the session. Unlocks only when the
  /// finish failed and the reader is still open.
  Future<void> _finishing(VoidCallback countFinished) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      _settlePendingRecitation();
      countFinished();
      await _finishChantSession();
    } finally {
      if (mounted && !_chantSessionFinished) {
        setState(() => _isFinishing = false);
      }
    }
  }

  Future<void> _addOfflineChantCount() async {
    final count = await showAddOfflineChantsDialog(context);
    if (count == null || count <= 0 || !mounted) return;

    final mantra = _chantMantra;
    if (mantra == null) return;

    // The personal save waits for the counter to seed. Run it off the app
    // container, not this widget's ref: closing the reader meanwhile would
    // drop the widget's listener, dispose the counter and lose the count
    // the user just confirmed.
    final container = ProviderScope.containerOf(context, listen: false);
    final added = _openedEndedAccumulator
        ? await addOfflineChantsToPersonal(
            container.read,
            container.listen,
            mantra,
            count,
          )
        : addOfflineChantsToSelection(ref.read, mantra, count);
    if (!mounted) return;
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.something_went_wrong)),
      );
      return;
    }
    if (!_openedEndedAccumulator) _tallyChants(mantra, count);
  }

  Future<void> _finishChantSession() async {
    final ctx = _chantContext;
    int? finishedSessionCount;
    if (ctx != null) {
      final sessionCount = _chantOpenedCount;
      await finishGroupAccumulatorSession(
        container: ProviderScope.containerOf(context, listen: false),
        groupAccumulatorId: ctx.groupAccumulatorId!,
        presetId: ctx.presetAccumulatorId!,
        groupId: ctx.groupId,
      );
      if (!mounted) return;
      _chantSessionFinished = true;
      finishedSessionCount = sessionCount;
    }
    if (mounted && (_isEmbedded || context.canPop())) {
      PlanNavigator.pop(context, finishedSessionCount);
    }
  }

  /// Create the audio controller when the reader was opened from a plan and the
  /// current item has resolvable audio (its own `audioUrl` wins over the
  /// day-level track). Auto-plays when the navigation requested it.
  ///
  /// A chant (chant list, routine, recitation collection) loads the
  /// library's recordings of the text; the play button starts the first, and
  /// the list play circle (`autoPlay`) starts it once they have loaded.
  void _initAudio() {
    final ctx = widget.navigationContext;
    if (ctx == null) return;
    if (ctx.source == NavigationSource.plan) {
      final item = ctx.currentItem;
      if (item == null) return;
      final url = ctx.effectiveAudioUrlFor(item);
      if (url == null) return;

      // Read now: the summary arrives from dispose, where `ref` is gone.
      final media = ref.read(mediaAnalyticsProvider);
      _audioController = PlanSegmentAudioController(
        url: url,
        startMs: item.startMs,
        endMs: item.endMs,
        onSegmentComplete: _onAudioSegmentComplete,
        onListened:
            (listen) => media.audioPlayed(
              surface: AudioSurface.plan,
              listened: listen.listened,
              speed: listen.speed,
              repeat: listen.repeat,
              completed: listen.completed,
              planId: ctx.planId,
              dayNumber: ctx.dayNumber,
              textId: widget.textId,
              eventId: ctx.isFromEvent ? ctx.eventId : null,
            ),
      );

      if (ctx.autoPlay) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _audioController?.maybeAutoPlay(),
        );
      }
      return;
    }

    if (!ctx.playsChantRecordings) return;
    final editionId = widget.textId.trim();
    if (editionId.isEmpty) return;
    final repository = ref.read(libraryRepositoryProvider);
    _chantRecordings = ChantRecordingsLoader(
      () => repository.getChantRecordings(editionId),
    )..addListener(_onChantRecordingsChanged);
    unawaited(_fetchChantRecordings(play: ctx.autoPlay));
  }

  /// Stops audio when the reader leaves or moves on to another text. The
  /// player stops at once, and a recordings lookup still in flight lands
  /// without starting a new one, which it otherwise could during the exit
  /// animation while this state is still mounted.
  void _stopAudio() {
    _chantRecordings?.cancelPending();
    _audioController?.cancel();
  }

  void _onChantRecordingsChanged() {
    if (mounted) setState(() {});
  }

  /// Loads the chant's recordings, then plays the first with [play]. A
  /// failure keeps a retry button where play would be; when the retry was
  /// the user's tap ([reportFailure]) a failure also says so.
  Future<void> _fetchChantRecordings({
    required bool play,
    bool reportFailure = false,
  }) async {
    final loader = _chantRecordings;
    if (loader == null) return;
    try {
      if (!await loader.fetch()) return;
    } catch (e) {
      _logger.warning('Chant recordings for ${widget.textId} failed', e);
      if (!mounted) return;
      setState(() => _chantRecordingsFailed = true);
      if (reportFailure) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.something_went_wrong)),
          );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _chantRecordingsFailed = false);
    if (play) _playCurrentCollectionAudio();
  }

  /// The recording play will start: the menu choice, or the first one.
  ChantAudioTrack? get _currentCollectionTrack =>
      ChantAudioTrack.toPlay(_chantTracks, _selectedCollectionTrack);

  @override
  void dispose() {
    // Left before the Undo window closed: the recitation still counts.
    _disposing = true;
    _pendingRecitation.commit();
    _audioController?.dispose();
    _chantRecordings
      ?..removeListener(_onChantRecordingsChanged)
      ..dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Swaps in [track] and starts it. When the file ends, playback stops
  /// and the play button can start the same recording again. The file's
  /// presigned link is fetched on play and again whenever it expires.
  void _replaceCollectionAudio(ChantAudioTrack track) {
    final repository = ref.read(libraryRepositoryProvider);
    final previous = _audioController;
    // Stop the old file now, but dispose it after this frame. The play
    // button and progress bar drop their listeners during the rebuild.
    previous?.cancel();
    final media = ref.read(mediaAnalyticsProvider);
    final ctx = widget.navigationContext;
    final surface = switch (ctx?.source) {
      NavigationSource.groupRecitationCollection ||
      NavigationSource.myRecitationCollection =>
        AudioSurface.recitationCollection,
      _ => AudioSurface.reader,
    };
    _audioController = chantRecordingAudioController(
      repository,
      track,
      onListened: (listen) => media.audioPlayed(
        surface: surface,
        listened: listen.listened,
        speed: listen.speed,
        repeat: listen.repeat,
        completed: listen.completed,
        textId: widget.textId,
        collectionId: ctx?.collectionId,
        eventId: (ctx?.isFromEvent ?? false) ? ctx?.eventId : null,
      ),
    );
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    unawaited(_audioController!.maybeAutoPlay());
  }

  /// Starts the chant's current recording. The list play circle passes the
  /// first one in; this is the reader's own play button.
  void _playCurrentCollectionAudio() {
    final track = _currentCollectionTrack;
    if (track == null) return;
    _selectedCollectionTrack = track;
    _replaceCollectionAudio(track);
    setState(() {});
  }

  Future<void> _openCollectionAudioSheet() async {
    final tracks = _chantTracks;
    if (tracks.isEmpty || !mounted) return;
    // The ⋮ sheet has just closed. Let that route finish before opening this one.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final nav = widget.navigationContext;
    final picked = await showGroupRecitationAudioSheet(
      context,
      tracks: tracks,
      selectedTrackId: _currentCollectionTrack?.id,
      groupName: nav?.groupTitle,
      imageUrl: nav?.collectionImageUrl,
    );
    if (!mounted || picked == null) return;
    _selectedCollectionTrack = picked;
    _replaceCollectionAudio(picked);
    setState(() {});
  }

  /// Called when the current item's audio finishes. Mirrors
  /// [SwipeNavigationWrapper]'s forward navigation: mark the subtask complete,
  /// clear transient reader UI, then advance to the next task with auto-play.
  /// Pops the sequence when there is no next task.
  void _onAudioSegmentComplete() {
    if (!mounted || _isAdvancing) return;
    final navContext = widget.navigationContext;
    if (navContext == null) return;

    _stopAudio();
    ref.read(planSubtaskCompletionProvider).completeCurrent(navContext);
    _clearTransientState();

    final didNavigate = PlanNavigator.navigateAdjacent(
      context,
      navContext,
      SwipeDirection.next,
      autoPlay: true,
    );

    if (didNavigate) {
      _isAdvancing = true;
    } else if (_isEmbedded || context.canPop()) {
      // Last task in the day — close the sequence.
      PlanNavigator.pop(context);
    }
  }

  // ─── Live recitation ─────────────────────────────────────────────────────

  void _onLiveStateChanged(
    RecitationLiveState? previous,
    RecitationLiveState next,
  ) {
    if (!mounted) return;
    if (next.isEnded && !(previous?.isEnded ?? false)) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.recitation_live_session_ended)),
        );
    }
    final position = next.position;
    if (position == null || !next.isFollowing) return;
    // Where the room already was is not the operator moving on: leave the
    // user on the text they opened. The content part pauses following for
    // them instead.
    if (next.positionIsSnapshot) return;
    final positionChanged = previous?.position != position;
    final followRequested = previous?.followRequest != next.followRequest;
    if (positionChanged || followRequested) _maybeSwitchLiveText(position);
  }

  /// The operator moved to another text of this sequence: go there. Texts
  /// outside the sequence are left alone (the content reports out of sync),
  /// so a stray id can never pull the user off their reading list.
  void _maybeSwitchLiveText(RecitationLivePosition position) {
    final navContext = widget.navigationContext;
    if (navContext == null || _isAdvancing) return;
    final state = ref.read(readerNotifierProvider(_params));
    final primaryVersionId = ref
        .read(readerDualSettingsProvider(_params.settingsScope))
        .primary
        .versionId;
    final onThisText =
        (navContext.currentItem?.hasSourceText(position.textId) ?? false) ||
        LivePositionResolver.textMatches(
          position,
          loadedTextIds: [
            widget.textId,
            state.textDetail?.id,
            primaryVersionId,
          ],
          content: state.content,
        );
    if (onThisText) return;

    final items = navContext.planTextItems;
    if (items == null) return;
    final index = items.indexWhere(
      (item) => item.hasSourceText(position.textId),
    );
    if (index < 0) return;
    final newContext = const NavigationService()
        .createNavigationContextForIndex(navContext, index);
    if (newContext == null) return;

    _isAdvancing = true;
    _stopAudio();
    if (navContext.source == NavigationSource.plan &&
        index > (navContext.currentTextIndex ?? -1)) {
      // Moving on with the group finishes this text, as a swipe would.
      ref.read(planSubtaskCompletionProvider).completeCurrent(navContext);
    }
    _clearTransientState();
    PlanNavigator.replace(context, items[index], newContext);
  }

  void _onScrollDirectionChanged(bool isScrollingDown) {
    if (!ReaderConstants.enableAppBarAutoHide) return;
    final host = PlanEmbeddedScope.maybeOf(context);
    host?.setContentScrollingDown(isScrollingDown);
    if (isScrollingDown && _isAppBarVisible) {
      setState(() {
        _isAppBarVisible = false;
      });
    } else if (!isScrollingDown && !_isAppBarVisible) {
      setState(() {
        _isAppBarVisible = true;
      });
    }
  }

  void _invalidatePlanProviders() {
    final navContext = widget.navigationContext;
    if (navContext == null || navContext.source != NavigationSource.plan) {
      return;
    }

    final planId = navContext.planId;
    final dayNumber = navContext.dayNumber;
    if (planId == null || dayNumber == null) return;

    ref.invalidate(
      userPlanDayContentFutureProvider(
        PlanDaysParams(planId: planId, dayNumber: dayNumber),
      ),
    );
    ref.invalidate(userPlanDaysCompletionStatusProvider(planId));
  }

  @override
  Widget build(BuildContext context) {
    for (final source in _sources) {
      ref.watch(
        prefetchBookmarkExistsProvider(
          BookmarkTarget(type: BookmarkType.text, sourceId: source.textId),
        ),
      );
    }

    final state = ref.watch(readerNotifierProvider(_params));
    final active = ref.watch(readerNotifierProvider(_activeParams));
    final activeNotifier = ref.read(
      readerNotifierProvider(_activeParams).notifier,
    );
    final readerTheme = _readerTheme(context);
    // The embedded host drops its video to audio while a panel is open.
    ref.listen(
      readerNotifierProvider(_activeParams).select((s) => s.hasSelection),
      (_, isPanelOpen) =>
          PlanEmbeddedScope.maybeOf(context)?.setPanelOpen(isPanelOpen),
    );

    final liveEventId = _liveEventId;
    if (liveEventId != null) {
      // Holds the event socket open for as long as this reader is on screen.
      ref.watch(recitationLiveProvider(liveEventId).select((s) => s.isVisible));
      ref.listen<RecitationLiveState>(
        recitationLiveProvider(liveEventId),
        _onLiveStateChanged,
      );
    }

    if (_isGroupAccumulatorChant) {
      final presetId = _chantContext!.presetAccumulatorId!;
      // Held open for the whole visit: chants are counted on these notifiers.
      ref.watch(joinedAccumulatorGroupsProvider(presetId));
      ref.watch(groupAccumulationCountsProvider(presetId));
      ref.watch(malaAccumulationSelectionProvider(presetId));
      ref.listen(
        malaAccumulationSelectionProvider(presetId),
        _onChantSelectionChanged,
      );
      ref.listen(joinedGroupUserCountsProvider(presetId), (_, next) {
        next.whenData((counts) {
          ref
              .read(groupAccumulationCountsProvider(presetId).notifier)
              .mergeFromServerCounts(counts);
        });
      });
    }

    final scaffold = Scaffold(
      backgroundColor: readerTheme.scaffoldBackgroundColor,
      body: _buildBody(context, state, active, activeNotifier),
    );
    // Embedded, the host owns leaving; there is no route of our own to pop.
    if (_isEmbedded) return Theme(data: readerTheme, child: scaffold);

    return Theme(
      data: readerTheme,
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) return;
          // Stop audio immediately so nothing plays during the exit animation.
          _stopAudio();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // Clear transient reader state after navigation finishes so this
            // cannot mutate Riverpod state while GoRouter rebuilds the tree.
            _clearTransientState();
            _invalidatePlanProviders();
            _settlePendingRecitation();
            if (_isGroupAccumulatorChant && !_chantSessionFinished) {
              unawaited(
                ref.read(malaSyncManagerProvider).flush(SyncReason.screenLeave),
              );
            }
          });
        },
        child: scaffold,
      ),
    );
  }

  ThemeData _readerTheme(BuildContext context) =>
      ReaderStyle.theme(context, ref);

  /// [state] is the first source's, which gates loading and errors;
  /// [active] is the tapped source's, which owns the selection and panels.
  Widget _buildBody(
    BuildContext context,
    ReaderState state,
    ReaderState active,
    ReaderNotifier activeNotifier,
  ) {
    final localizations = context.l10n;
    // Loading state; also the first frame, before the initial fetch starts.
    if (state.isLoading || state.status == ReaderStatus.initial) {
      return _buildStatusView(
        context,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(localizations.loading),
            ],
          ),
        ),
      );
    }

    // Error / empty content state — always reachable back navigation so the
    // user is never trapped on a dead-end screen. Technical exception text is
    // never surfaced; we show a friendly, localized message instead.
    if (state.isError || state.textDetail == null) {
      // Says what went wrong: no connection, the server, or no such text.
      final (title, message) = switch (state.isError ? state.errorKind : null) {
        LoadErrorKind.connection => (
          localizations.error_offline_title,
          localizations.unableToLoad,
        ),
        LoadErrorKind.server => (
          localizations.error_server_title,
          localizations.reader_error_server_message,
        ),
        LoadErrorKind.missing ||
        null => (localizations.no_content, localizations.noContentAvailable),
      };
      return _buildStatusView(
        context,
        child: _ReaderErrorView(
          title: title,
          message: message,
          retryLabel: localizations.retry,
          backLabel: localizations.back,
          onRetry: () =>
              ref.read(readerNotifierProvider(_params).notifier).reload(),
          onBack: () => _navigateBack(context),
        ),
      );
    }

    // A selected verse has its sheet open below the text.
    final isPanelOpen = active.hasSelection;
    // The play button and audio bar share the navigation strip's layout.
    // When the strip is away for another reason (a commentary, a group
    // accumulation chant), the button floats over the text on its own.
    final showAudioOnNav =
        _hasAudio && SwipeNavigationWrapper.showsBottomBar(active);
    final isBottomOverlayVisible = !isPanelOpen && _hasAudio && !showAudioOnNav;
    final chantBarHeight = _isGroupAccumulatorChant
        ? GroupAccumulatorChantBar.barHeight
        : 0.0;
    final chantMantra = _chantMantra;
    // Watched here rather than where the footer is built, so an open panel
    // hiding the footer does not let go of the selected target's counter.
    final isChantTargetReady =
        chantMantra != null && _watchChantTargetReady(chantMantra);
    final contentBottomPadding =
        (showAudioOnNav
            ? (_bottomBarHeight > 0
                  ? _bottomBarHeight + 16
                  : _selectedSegmentOverlayFallbackHeight)
            : isBottomOverlayVisible
            ? (_bottomOverlayHeight > 0
                  ? _bottomOverlayHeight + 16
                  : _selectedSegmentOverlayFallbackHeight)
            : _defaultContentBottomPadding) +
        chantBarHeight;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final chantFooter =
        chantMantra != null && !isPanelOpen && !_openedEndedAccumulator
        ? GroupAccumulatorChantFooter(
            // The recitation just finished counts as one completed, unless
            // Finish and count has already counted it.
            completedCount:
                _recitationsCounted + (_finishedRecitationCounted ? 0 : 1),
            onReciteAgain: _onReciteAgain,
            onFinishAndCount: _finishAndCount,
            onFinishWithoutCounting: _finishWithoutCounting,
            canCount: isChantTargetReady,
            isFinishing: _isFinishing,
          )
        : null;

    return Stack(
      children: [
        // Audio in the background of an open panel: keep the button alive
        // (playing or paused) but paint it *under* the content so the opaque
        // panel covers it. Rendered first so it sits behind everything.
        if (_hasAudio && isPanelOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + _audioBottomGap,
            child: Center(child: _buildAudioButton()),
          ),
        // The status bar dims with the text while a verse's sheet is open.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.paddingOf(context).top,
          child: _verseSheetDim(isPanelOpen),
        ),
        // Main content area
        SafeArea(
          child: Column(
            children: [
              // Focus mode: the app bar slides up out of view on scroll-down.
              SlideAwayHeader(
                visible: _isAppBarVisible,
                duration: ReaderConstants.focusModeDuration,
                curve: ReaderConstants.focusModeCurve,
                // Dimmed with the text while a verse's sheet is open (WF13).
                child: Stack(
                  children: [
                    _buildAppBar(context),
                    Positioned.fill(child: _verseSheetDim(isPanelOpen)),
                  ],
                ),
              ),
              // Main scrollable content
              Expanded(
                child: SwipeNavigationWrapper(
                  params: _activeParams,
                  textDetail: state.textDetail!,
                  isAppBarVisible: _isAppBarVisible,
                  aboveBottomBar: showAudioOnNav
                      ? _buildAudioCluster(gap: _playBarGap)
                      : null,
                  onBottomBarHeight: (height) {
                    if ((_bottomBarHeight - height).abs() < 1) return;
                    setState(() => _bottomBarHeight = height);
                  },
                  child: ReaderVerseSplitView(
                    params: _activeParams,
                    mainContent: ReaderContentPart(
                      sources: _sources,
                      initialSegmentId: widget.segmentId,
                      bottomPadding: contentBottomPadding,
                      chantSessionFooter: chantFooter,
                      chantRecitationCount: _recitationsCounted,
                      onSourceSelected: _onSourceSelected,
                      onScrollDirectionChanged: _onScrollDirectionChanged,
                      progress: _progress,
                      onScrollToTopReady: (scrollFn) {
                        _scrollToTop = scrollFn;
                      },
                    ),
                  ),
                ),
              ),
              if (chantMantra != null)
                GroupAccumulatorChantBar(
                  mantra: chantMantra,
                  sessionCount: _recitationsCounted,
                  chantTitle: state.openedText!.title,
                  chantTitleFontFamily: getFontFamily(
                    state.openedText!.language,
                  ),
                  showSessionPill: !_openedEndedAccumulator,
                ),
            ],
          ),
        ),
        // An open verse sheet carries its colour down under the home
        // indicator, which the SafeArea above leaves showing the page.
        if (isPanelOpen && chantMantra == null && bottomInset > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset,
            child: Builder(
              // Read under the reader's Theme, not this State's context.
              builder: (context) => ColoredBox(
                color: ReaderPalette.resolve(
                  Theme.of(context),
                  ref,
                ).drawerBackground,
              ),
            ),
          ),
        // The floating audio button, while the navigation strip is away for
        // a reason other than a verse sheet.
        if (isBottomOverlayVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: chantBarHeight,
            child: _MeasuredSize(
              onChange: (size) {
                if ((_bottomOverlayHeight - size.height).abs() < 1) return;
                setState(() => _bottomOverlayHeight = size.height);
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset + _audioBottomGap),
                child: Center(child: _buildAudioButton()),
              ),
            ),
          ),
      ],
    );
  }

  /// The dim over what sits above an open verse sheet, as over the text
  /// (see [ReaderVerseSplitView.dim]); taps pass through it.
  Widget _verseSheetDim(bool open) => IgnorePointer(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: Colors.black.withValues(
        alpha: open ? ReaderVerseSplitView.dim : 0,
      ),
    ),
  );

  /// The follow control whenever a recitation is being followed, including a
  /// plan task that is not itself live. A static label when the task is live
  /// and nothing is being followed. Other screens keep the event pill.
  Widget? _livePill(String? liveEventId) {
    final pill = planLivePill(
      taskIsLive: widget.navigationContext?.planTaskIsLive,
      followsRecitation: liveEventId != null,
    );
    return switch (pill) {
      PlanLivePill.hidden => null,
      PlanLivePill.staticLabel => const PlanTaskLiveLabel(),
      PlanLivePill.syncToggle => RecitationLiveSyncToggle(
        eventId: liveEventId!,
      ),
    };
  }

  /// Embedded: a close bar with font size and languages instead of the app bar.
  /// Either bar carries the live sync button when following an event.
  Widget _buildAppBar(BuildContext context) {
    final eventId = _eventId;
    final liveEventId = _liveEventId;
    final liveSyncToggle = _livePill(liveEventId);
    final prayerRequestsButton = eventId == null
        ? null
        : PrayerRequestsIconButton(eventId: eventId);
    if (_isEmbedded) {
      return PlanEmbeddedHeader(
        onClose: _closeEmbedded,
        actions: [
          if (liveSyncToggle != null) liveSyncToggle,
          if (prayerRequestsButton != null) prayerRequestsButton,
          ReaderFontSizeButton(onPressed: () => _openDisplaySheet(context)),
          ReaderLanguagesButton(onPressed: () => _openLanguagesSheet(context)),
        ],
      );
    }
    return ReaderAppBarOverlay(
      params: _activeParams,
      progress: _progress,
      liveSyncToggle: liveSyncToggle,
      prayerRequestsButton: prayerRequestsButton,
      // Picking a result replaces the route without the event, which drops
      // the live sync, so the reader that follows a recitation has no search.
      onSearchPressed: liveEventId == null
          ? () => _handleSearch(context)
          : null,
      onLanguagesPressed: () => _openLanguagesSheet(context),
      // The event page already offers share and offline recitations, so the
      // menu goes there.
      onMorePressed: eventId == null
          ? () => _openMoreBottomSheet(context)
          : null,
      onFontSizePressed: () => _openDisplaySheet(context),
    );
  }

  /// The embedded host has no route of its own, so the leave work that the
  /// route's PopScope would do (see [build]) runs here instead.
  void _closeEmbedded() {
    _stopAudio();
    _invalidatePlanProviders();
    _settlePendingRecitation();
    if (_isGroupAccumulatorChant && !_chantSessionFinished) {
      unawaited(
        ref.read(malaSyncManagerProvider).flush(SyncReason.screenLeave),
      );
    }
    PlanNavigator.pop(context);
  }

  /// Play button with the progress line and speed control under it.
  /// Group recitations also show the recording title; plan tasks do not.
  Widget _buildAudioCluster({required double gap}) {
    final title = _audioVersionTitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _buildAudioButton()),
        SizedBox(height: gap),
        PlanAudioPlayerBar(
          controller: _audioController,
          versionTitle: title,
          onVersionTap: title == null
              ? null
              : () => unawaited(_openCollectionAudioSheet()),
          onSettingChanged: (setting, value) => ref
              .read(mediaAnalyticsProvider)
              .audioSettingChanged(setting: setting, value: value),
        ),
      ],
    );
  }

  /// Recording name from the backend, for a group recitation that has one.
  String? get _audioVersionTitle {
    if (!_hasCollectionAudioChoices) return null;
    final title = _currentCollectionTrack?.title.trim();
    if (title == null || title.isEmpty) return null;
    return title;
  }

  /// The floating play control. Plan audio toggles the current segment.
  /// A group collection plays its current recording: the first one, or the
  /// one picked from Audio versions. Pause and a later play stay on that file.
  Widget _buildAudioButton() {
    if (_showsChantRetry) {
      return ChantAudioRetryButton(
        isLoading: _chantRecordings?.isLoading ?? false,
        onPressed:
            () => unawaited(
              _fetchChantRecordings(play: true, reportFailure: true),
            ),
      );
    }
    if (_hasCollectionAudioChoices) {
      final controller = _audioController;
      if (controller != null) {
        return PlanAudioButton(key: _audioButtonKey, controller: controller);
      }
      return CollectionAudioPlayButton(onPressed: _playCurrentCollectionAudio);
    }
    return PlanAudioButton(key: _audioButtonKey, controller: _audioController!);
  }

  /// Wraps a status view (loading / error / empty) in a [SafeArea] with a
  /// minimal app bar that always exposes a back button. This guarantees the
  /// user can leave the screen even when content fails to load.
  Widget _buildStatusView(BuildContext context, {required Widget child}) {
    if (_isEmbedded) {
      return Column(
        children: [
          PlanEmbeddedHeader(onClose: () => _navigateBack(context)),
          Expanded(child: child),
        ],
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                tooltip: context.l10n.back,
                onPressed: () => _navigateBack(context),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  /// Pops back if possible, otherwise falls back to the home route so the user
  /// is never stranded (e.g. when arriving via a deep link with no history).
  void _navigateBack(BuildContext context) {
    if (_isEmbedded || context.canPop()) {
      PlanNavigator.pop(context);
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// Searches the active source's text.
  Future<void> _handleSearch(BuildContext context) async {
    final router = ref.read(appRouterProvider);
    final textId = _activeParams.textId;
    final language = ref
        .read(readerNotifierProvider(_activeParams))
        .textDetail
        ?.language;

    // Close selection before search
    _clearTransientState();

    final result = await showSearch<Map<String, String>?>(
      context: context,
      delegate: ReaderSearchDelegate(
        ref: ref,
        textId: textId,
        language: language,
      ),
    );

    if (result != null && mounted) {
      final selectedTextId = result['textId']!;
      final selectedSegmentId = result['segmentId']!;

      if (selectedTextId == textId) {
        router.pushReplacement(
          '/reader/$selectedTextId',
          extra: NavigationContext(
            source: NavigationSource.search,
            targetSegmentId: selectedSegmentId,
          ),
        );
      }
    }
  }

  /// Sizes, fonts and background, for the lines the active source shows.
  void _openDisplaySheet(BuildContext context) {
    final state = ref.read(readerNotifierProvider(_activeParams));
    showReaderDisplaySheet(
      context,
      scope: _activeParams.settingsScope,
      originalLanguage: state.textDetail?.language,
      onChangeLanguages: () => _openLanguagesSheet(context),
    );
  }

  /// Lays out the active source's text; the page's other loaded texts
  /// follow each pick. One not loaded yet takes it up when it loads.
  Future<void> _openLanguagesSheet(BuildContext context) async {
    _clearTransientState();

    final state = ref.read(readerNotifierProvider(_activeParams));
    final scopes = {_activeParams.settingsScope};
    final others = <ReaderLanguagesText>[];
    for (final params in _sources) {
      if (!scopes.add(params.settingsScope)) continue;
      if (!ref.exists(readerNotifierProvider(params))) continue;
      final textDetail = ref.read(readerNotifierProvider(params)).textDetail;
      if (textDetail == null) continue;
      others.add(
        ReaderLanguagesText(
          scope: params.settingsScope,
          primaryDisplay: _primaryDisplayOf(textDetail),
        ),
      );
    }

    await showReaderLanguagesSheet(
      context,
      scope: _activeParams.settingsScope,
      primaryDisplay: _primaryDisplayOf(state.textDetail),
      sourceSample: scriptDetectionSample(state.content),
      others: others,
    );
  }

  /// Snapshot of a loaded text so the drawer can show it as "Original".
  ReaderSlotConfig _primaryDisplayOf(TextDetail? textDetail) {
    final languageCode = textDetail?.language ?? 'en';
    return ReaderSlotConfig(
      languageCode: languageCode,
      languageLabel: getLanguageName(languageCode, context),
      versionId: textDetail?.id,
      versionLabel: textDetail?.title,
    );
  }

  void _openMoreBottomSheet(BuildContext context) {
    _clearTransientState();

    // Adds the edition the user opened, not the original it is shown under.
    final openedText = ref
        .read(readerNotifierProvider(_activeParams))
        .openedText;
    final showAddToPractices =
        (widget.navigationContext?.source == NavigationSource.recitationList ||
            widget.navigationContext?.source == NavigationSource.routine) &&
        openedText != null;

    showReaderMoreBottomSheet(
      context,
      textId: _activeParams.textId,
      showAddToPractices: showAddToPractices,
      showOfflineRecitation: _isGroupAccumulatorChant,
      onAddToPractices: showAddToPractices
          ? () => _openRoutineWithRecitation(context, openedText)
          : null,
      onAddOfflineRecitation: _isGroupAccumulatorChant
          ? _addOfflineChantCount
          : null,
      onAudioVersions: _hasCollectionAudioChoices
          ? () => _openCollectionAudioSheet()
          : null,
    );
  }

  void _openRoutineWithRecitation(BuildContext context, TextDetail textDetail) {
    context.push(
      AppRoutes.practiceEditRoutine,
      extra: {
        'initialRecitation': RecitationModel(
          textId: _activeParams.textId,
          title: textDetail.title,
          language: textDetail.language,
        ),
      },
    );
  }
}

/// Friendly, centered error/empty state for the reader with retry and back
/// actions. Intentionally hides raw exception details from the user.
class _ReaderErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String retryLabel;
  final String backLabel;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ReaderErrorView({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.backLabel,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: Text(backLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasuredSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;

  const _MeasuredSize({required this.child, required this.onChange});

  @override
  State<_MeasuredSize> createState() => _MeasuredSizeState();
}

class _MeasuredSizeState extends State<_MeasuredSize> {
  Size? _oldSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifySize());
  }

  @override
  void didUpdateWidget(covariant _MeasuredSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifySize());
  }

  void _notifySize() {
    if (!mounted) return;
    final size = context.size;
    if (size == null || size == _oldSize) return;
    _oldSize = size;
    widget.onChange(size);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
