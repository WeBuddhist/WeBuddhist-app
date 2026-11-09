part of 'mala_screen.dart';

/// Key for the group counts state of a single-accumulation mala, kept apart
/// from every preset-keyed state so unrelated accumulations never share it.
String groupMantraCountsKey(String groupAccumulatorId) =>
    'group:$groupAccumulatorId';

/// Single-accumulation mode: one group accumulation's own mantra, such as a
/// space mantra that is not in the public preset list, counted only into
/// that accumulation.
///
/// There is no preset here, so the carousel, the personal-or-group switch,
/// bookmarks, sharing and add-to-practice are left out.
class GroupMantraMalaScreen extends ConsumerStatefulWidget {
  const GroupMantraMalaScreen({
    super.key,
    required this.detail,
    required this.mantra,
    this.source,
  });

  final GroupAccumulatorDetail detail;
  final MantraText mantra;

  /// Where the screen was opened from, carried on `mala_screen_opened`.
  final String? source;

  @override
  ConsumerState<GroupMantraMalaScreen> createState() =>
      _GroupMantraMalaScreenState();
}

class _GroupMantraMalaScreenState extends ConsumerState<GroupMantraMalaScreen> {
  late final MalaSessionTracker _session;
  late final MalaSyncManager _sync;

  /// True until the server's count for this accumulation has been merged (or
  /// the fetch failed and the local count is used, as in preset mode).
  bool _seeding = true;

  String get _accumulatorId => widget.detail.id;
  String get _countsKey => groupMantraCountsKey(_accumulatorId);

  /// Drawing-only stand-in for [MantraSwitcher]. Its [Mantra.presetId] is the
  /// counts key, never a real preset id, and it is never passed to a
  /// preset-keyed provider.
  late final Mantra _displayMantra = Mantra(
    presetId: _countsKey,
    beadImageUrl: widget.mantra.beadImageUrl,
    mantra: widget.mantra,
  );

  String get _title {
    final title = widget.mantra.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return widget.detail.title;
  }

  @override
  void initState() {
    super.initState();
    final analytics = ref.read(malaAnalyticsProvider);
    _session = MalaSessionTracker(analytics)..start();
    _sync = ref.read(malaSyncManagerProvider);
    analytics.screenOpened(
      presetId: null,
      groupAccumulatorId: _accumulatorId,
      mantraId: widget.mantra.id,
      mantraName: _title,
      mode: MalaMode.group,
      groupId: widget.detail.groupId,
      source: widget.source,
    );
    unawaited(_seed());
  }

  @override
  void dispose() {
    _session.dispose();
    // Best-effort flush of this accumulation's tail as the screen leaves.
    unawaited(_sync.flush(SyncReason.screenLeave));
    super.dispose();
  }

  /// Seeds the count from the server, since the server ignores a lower
  /// `current_count` and chants counted on a stale base would be lost.
  Future<void> _seed() async {
    final language = ref.read(contentLanguageProvider);
    final result = await ref
        .read(groupAccumulatorRepositoryProvider)
        .refreshGroupAccumulator(_accumulatorId, language: language);
    if (!mounted) return;
    final serverTotal = result.fold(
      (_) => null,
      (detail) => detail.user?.totalCount ?? 0,
    );
    if (serverTotal != null) {
      await ref
          .read(groupAccumulationCountsProvider(_countsKey).notifier)
          .mergeFromServerCounts({_accumulatorId: serverTotal});
    }
    if (mounted) setState(() => _seeding = false);
  }

  Uint8List? _beadImageBytes() {
    // The accumulation's resolved skin first, then the mantra's default.
    final urls = <String>[
      for (final url in [widget.detail.malaImageUrl, widget.mantra.beadImageUrl])
        if (url != null && url.isNotEmpty) url,
    ];
    for (final url in urls.toSet()) {
      final image = ref.watch(malaBeadImageBytesProvider(url));
      if (image.isLoading) return null;
      final bytes = image.valueOrNull;
      if (bytes != null) return bytes;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final settings = ref.watch(malaSettingsProvider);
    final leftHanded = settings.leftHanded;
    ref.watch(groupAccumulationCountsProvider(_countsKey));
    final countsNotifier = ref.read(
      groupAccumulationCountsProvider(_countsKey).notifier,
    );
    final beadImageBytes = _beadImageBytes();
    final hasDeityImage = _displayMantra.deityImage != null;

    const beadsPerRound = kBeadsPerRound;
    final displayTotal = _seeding ? 0 : countsNotifier.countFor(_accumulatorId);
    final displayBeadInRound = displayTotal % beadsPerRound;
    final displayRounds = displayTotal ~/ beadsPerRound;

    void onBead(MalaInput input) {
      if (_seeding) return;
      final total = countsNotifier.increment(
        groupAccumulatorId: _accumulatorId,
        groups: const [],
        soundEnabled: settings.soundEnabled,
        vibrationEnabled: settings.vibrationEnabled,
        beadsPerRound: beadsPerRound,
      );
      // Null means the tap was ignored, so no bead was counted.
      if (total == null) return;
      _session.onBead(
        presetId: null,
        groupAccumulatorId: _accumulatorId,
        mantraId: widget.mantra.id,
        mantraName: _title,
        mode: MalaMode.group,
        groupId: widget.detail.groupId,
        total: total,
        roundComplete: total % beadsPerRound == 0,
        input: input,
      );
    }

    return Scaffold(
      body: ClipRect(
        child: SafeArea(
          child: Column(
            children: [
              _MalaAppBar(
                title: _title,
                leftHanded: leftHanded,
                onHandLayoutPressed:
                    () => ref
                        .read(malaSettingsProvider.notifier)
                        .setLeftHanded(!leftHanded),
                onMorePressed: () => MalaPracticeSettingsSheet.show(context),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: hasDeityImage ? 48 : 26,
                        child: MantraSwitcher(
                          mantras: [_displayMantra],
                          language: language,
                          tibetanFontFamily: AppConfig.tibetanContentFont,
                          index: 0,
                          speedFactor: settings.mantraSpeed,
                          onIndexChanged: (_) {},
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_seeding)
                        MalaCountSkeleton(alignEnd: leftHanded)
                      else
                        _CounterBlock(
                          beadInRound: displayBeadInRound,
                          beadsPerRound: beadsPerRound,
                          rounds: displayRounds,
                          leftHanded: leftHanded,
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        flex: hasDeityImage ? 30 : 42,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                height: constraints.maxHeight * 0.85,
                                width: double.infinity,
                                child: MalaBeads(
                                  key: ValueKey(_countsKey),
                                  total: displayTotal,
                                  beadInRound: displayBeadInRound,
                                  beadsPerRound: beadsPerRound,
                                  enabled: !_seeding,
                                  mirrored: leftHanded,
                                  beadImageBytes: beadImageBytes,
                                  beadColor: const Color(0xFF8D6E63),
                                  threadColor: const Color(0xFFC62828),
                                  onTap: () => onBead(MalaInput.tap),
                                  onSwipe: () => onBead(MalaInput.swipe),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
