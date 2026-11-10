import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/config/router/app_routes.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/widgets/responsive_cover_image.dart';
import 'package:flutter_pecha/core/widgets/slide_away_header.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_event.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_analytics.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_live_utils.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_event_live_player.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_event_live_toggles.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_event_replays_menu.dart';
import 'package:flutter_pecha/features/plans/data/models/plan_video_model.dart';
import 'package:flutter_pecha/features/plans/presentation/utils/event_replays.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_embedded_host.dart';
import 'package:flutter_pecha/features/plans/presentation/widgets/plan_navigation/plan_embedded_panel.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What the event page hands the online collection screen.
class GroupEventCollectionLiveArgs {
  const GroupEventCollectionLiveArgs({
    required this.event,
    required this.navigationContext,
  });

  final GroupEvent event;

  /// Opens on the collection item the reader starts with.
  final NavigationContext navigationContext;
}

enum _LiveStatus { loading, live, none, failed }

/// An online attendee's view of a collection event: the stream pinned on
/// top, the collection's reader below it. It is the plan event layout with
/// no days or task list: the reader opens straight away and closing it
/// leaves the screen.
class GroupEventCollectionLiveScreen extends ConsumerStatefulWidget {
  const GroupEventCollectionLiveScreen({super.key, required this.args});

  final GroupEventCollectionLiveArgs args;

  @override
  ConsumerState<GroupEventCollectionLiveScreen> createState() =>
      _GroupEventCollectionLiveScreenState();
}

class _GroupEventCollectionLiveScreenState
    extends ConsumerState<GroupEventCollectionLiveScreen> {
  final _embedded = PlanEmbeddedController();
  late String _liveLanguage;
  bool _liveAudioOnly = false;
  bool _leaving = false;

  /// YouTube ids of the streams seen live, by language. They keep the page
  /// live and stay out of the Replays menu.
  final Map<String, String> _liveStreams = {};

  /// Recording picked from the Replays menu; null plays the live stream.
  EventReplay? _replay;

  GroupEvent get _event => widget.args.event;

  @override
  void initState() {
    super.initState();
    _liveLanguage = GroupEventLiveUtils.initialLanguage(
      ref.read(contentLanguageProvider),
    );
    final navigationContext = widget.args.navigationContext;
    final item = navigationContext.currentItem;
    if (item != null) {
      // Closing the reader (its close button, or Finish on the last chant)
      // ends the visit: there is no list to return to here.
      unawaited(
        _embedded.open<void>(item, navigationContext).then((_) => _leave()),
      );
    }
    _embedded.addListener(_onEmbeddedChanged);
    if (item == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    }
  }

  @override
  void dispose() {
    _embedded.removeListener(_onEmbeddedChanged);
    _embedded.dispose();
    super.dispose();
  }

  void _onEmbeddedChanged() {
    if (mounted) setState(() {});
  }

  void _leave() {
    if (!mounted || _leaving) return;
    _leaving = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// A commentary / versions panel forces audio; the user's choice returns
  /// once it closes.
  bool get _audioOnly => _liveAudioOnly || _embedded.isPanelOpen;

  /// Audio mode slides the top chrome away on scroll-down; video stays pinned.
  bool get _chromeVisible => !(_audioOnly && _embedded.isContentScrollingDown);

  GroupEventLanguageKey get _liveKey => (
    eventId: _event.id,
    language: _liveLanguage,
  );

  /// The event as last fetched in the stream language, or the one the event
  /// page passed in until then.
  GroupEvent _liveEvent({bool listen = true}) {
    final provider = groupEventInLanguageProvider(_liveKey);
    final async = listen ? ref.watch(provider) : ref.read(provider);
    return async.valueOrNull?.fold((_) => null, (event) => event) ?? _event;
  }

  /// Same rules as the plan event page: sticky per language once a stream
  /// was seen, and only a successful answer with no stream ends it.
  _LiveStatus _liveStatus() {
    final eventAsync = ref.watch(groupEventInLanguageProvider(_liveKey));
    final either = eventAsync.valueOrNull;
    if (either == null) {
      if (_liveStreams.isNotEmpty) return _LiveStatus.live;
      return eventAsync.hasError ? _LiveStatus.failed : _LiveStatus.loading;
    }
    final status = either.fold(
      (failure) =>
          failure is NotFoundFailure ? _LiveStatus.none : _LiveStatus.failed,
      (event) {
        final videoId = GroupEventLiveUtils.videoIdOf(event);
        if (videoId == null) return _LiveStatus.none;
        if (_liveStreams.isEmpty &&
            GroupEventLiveUtils.hasEnded(event, DateTime.now())) {
          return _LiveStatus.none;
        }
        _liveStreams[_liveLanguage] = videoId;
        return _LiveStatus.live;
      },
    );
    if (status == _LiveStatus.none) _liveStreams.remove(_liveLanguage);
    return _liveStreams.isNotEmpty ? _LiveStatus.live : status;
  }

  bool _knowsStream(_LiveStatus live) =>
      live != _LiveStatus.loading && live != _LiveStatus.failed;

  /// A collection has no days, so its recordings are the event's own
  /// YouTube links, minus the streams that are live right now.
  List<EventReplay> _replays(GroupEvent event) {
    final videos = [
      for (final link in event.youtube)
        if (link.url.trim().isNotEmpty)
          PlanVideoModel(
            id: link.id,
            url: link.url.trim(),
            videoId: '',
            title: link.label,
            displayOrder: link.displayOrder,
          ),
    ];
    return EventReplays.of(
      videos,
      dayNumber: 1,
      excludeVideoIds: _liveStreams.values,
    );
  }

  void _openReplay(EventReplay replay) {
    setState(() => _replay = replay);
    ref
        .read(groupEventAnalyticsProvider)
        .eventReplayOpened(
          eventId: _event.id,
          groupId: _event.groupId,
          dayNumber: replay.dayNumber,
          session: replay.session,
          videoId: replay.videoId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final live = _liveStatus();
    final event = _liveEvent();
    final replays =
        _knowsStream(live) ? _replays(event) : const <EventReplay>[];
    // Once the stream is over, the first recording plays in its place, as
    // on a plan's day; before the start the countdown keeps the slot.
    final start = event.startDate;
    final hasBegun = start == null || !DateTime.now().isBefore(start);
    final autoReplay =
        live == _LiveStatus.none && replays.isNotEmpty && hasBegun
            ? replays.first
            : null;
    final replay = _replay ?? autoReplay;

    return PopScope(
      canPop: !_embedded.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _embedded.close();
      },
      child: Scaffold(
        body: PlanEmbeddedScope(
          controller: _embedded,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Stays mounted while hidden so the live player keeps playing.
                SlideAwayHeader(
                  visible: _chromeVisible,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAppBar(
                        live: live,
                        replays: replays,
                        replay: replay,
                      ),
                      _buildHeader(event, live: live, replay: replay),
                      if (_replay != null && live == _LiveStatus.live)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: GroupEventBackToLivePill(
                              onTap: () => setState(() => _replay = null),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: PlanEmbeddedPanel(controller: _embedded)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The reader's own header carries prayer requests, so this bar holds
  /// only the Replays menu and the player toggles.
  AppBar _buildAppBar({
    required _LiveStatus live,
    required List<EventReplay> replays,
    required EventReplay? replay,
  }) {
    final isLive = live == _LiveStatus.live;
    final showsPlayer = isLive || replay != null;
    return AppBar(
      primary: false,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(AppAssets.arrowLeft),
        tooltip: context.l10n.back,
        onPressed: _embedded.isOpen ? _embedded.close : _leave,
      ),
      title:
          _knowsStream(live)
              ? GroupEventReplaysMenu(
                replays: replays,
                selected: replay,
                onSelected: _openReplay,
              )
              : null,
      actions:
          showsPlayer
              ? [
                GroupEventMediaToggle(
                  audioOnly: _audioOnly,
                  onChanged:
                      (audioOnly) => setState(() => _liveAudioOnly = audioOnly),
                ),
                if (isLive) ...[
                  const SizedBox(width: 8),
                  GroupEventLanguageToggle(
                    language: _liveLanguage,
                    onChanged:
                        (language) => setState(() => _liveLanguage = language),
                  ),
                ],
                const SizedBox(width: 12),
              ]
              : null,
      elevation: 0,
    );
  }

  Widget _buildHeader(
    GroupEvent event, {
    required _LiveStatus live,
    required EventReplay? replay,
  }) {
    return GroupEventLiveHeader(
      eventId: event.id,
      language: _liveLanguage,
      audioOnly: _audioOnly,
      fallbackTitle: event.title,
      showsStream: live != _LiveStatus.none,
      replay:
          replay == null
              ? null
              : GroupEventReplay(
                videoId: replay.videoId,
                title: EventReplays.label(
                  context.l10n,
                  Localizations.localeOf(context).languageCode,
                  replay,
                ),
              ),
      notStartedBackground: ResponsiveCoverImage(
        image: event.image,
        fit: BoxFit.cover,
      ),
    );
  }
}
