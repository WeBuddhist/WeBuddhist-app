import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/core.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/utils/tibetan_numerals.dart';
import 'package:flutter_pecha/core/widgets/screen_cache_builder.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_accumulator.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_accumulator_practice_launcher.dart';
import 'package:flutter_pecha/features/mala/domain/entities/accumulator_group.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/accumulator_groups_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/group_accumulation_counts_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_accumulation_selection_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_settings_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_sync_manager.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/space_mantra_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/add_mala_rounds_button.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/group_accumulations_bar.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_beads.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_skeleton.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mantra_switcher.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_settings_sheet.dart';
import 'package:flutter_pecha/features/practice/data/datasource/bookmark_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/bookmark_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MalaScreen extends ConsumerStatefulWidget {
  const MalaScreen({
    super.key,
    this.initialPresetId,
    this.initialGroupAccumulatorId,
    this.openedFromEndedAccumulator = false,
    this.singleAccumulation,
    this.source,
  });

  /// Optionally open directly on a specific mantra.
  final String? initialPresetId;

  /// When set (e.g. from a group accumulator screen), pre-select that group
  /// accumulation instead of the last-used personal/group choice.
  final String? initialGroupAccumulatorId;

  /// Recite now opened a finished accumulation. Beads still count into it.
  /// The switcher and add-rounds controls stay hidden.
  final bool openedFromEndedAccumulator;

  /// Single-accumulation mode: only this group accumulation's own mantra,
  /// counted only into it, with no preset carousel. Its mantra must be set.
  final GroupAccumulator? singleAccumulation;

  /// Where the screen was opened from, carried on `mala_screen_opened`.
  final String? source;

  @override
  ConsumerState<MalaScreen> createState() => _MalaScreenState();
}

/// What the counter, beads and controls show for the current carousel item:
/// a public preset, or a group accumulation's own mantra.
class _MalaPractice {
  const _MalaPractice({
    required this.title,
    required this.onMorePressed,
    required this.showCountSkeleton,
    required this.displayTotal,
    required this.beadsPerRound,
    required this.countingEnabled,
    required this.beadImageBytes,
    required this.beadsKey,
    required this.onBead,
    this.onSeedRetry,
    this.addRounds,
    this.footer,
  });

  final String title;
  final VoidCallback onMorePressed;
  final bool showCountSkeleton;
  final int displayTotal;
  final int beadsPerRound;
  final bool countingEnabled;
  final Uint8List? beadImageBytes;
  final String beadsKey;
  final void Function(MalaInput input) onBead;

  /// Set when the count failed to load; the beads show a retry instead.
  final VoidCallback? onSeedRetry;
  final Widget? addRounds;
  final Widget? footer;
}

class _MalaScreenState extends ConsumerState<MalaScreen> {
  int _index = 0;
  bool _initialisedIndex = false;
  bool _appliedInitialGroupSelection = false;
  bool _trackedOpened = false;
  late final MalaSessionTracker _session;
  late final MalaSyncManager _sync;

  @override
  void initState() {
    super.initState();
    _session = MalaSessionTracker(ref.read(malaAnalyticsProvider))..start();
    _sync = ref.read(malaSyncManagerProvider);
  }

  @override
  void dispose() {
    _session.dispose();
    // Best-effort flush of any group tail as the screen leaves. A preset's
    // personal tail is flushed by its counter.
    unawaited(_sync.flush(SyncReason.screenLeave));
    super.dispose();
  }

  /// Once per screen, after the persisted selection has loaded so `mode` is
  /// the one the user will count into.
  void _trackOpened(Mantra mantra) {
    if (_trackedOpened) return;
    _trackedOpened = true;
    final presetId = mantra.presetId;
    final selectionProvider = malaAccumulationSelectionProvider(presetId);
    unawaited(
      ref.read(selectionProvider.notifier).loaded.then((_) {
        if (!mounted) return;
        final selection = ref.read(selectionProvider);
        final groups =
            ref.read(joinedAccumulatorGroupsProvider(presetId)).valueOrNull;
        ref
            .read(malaAnalyticsProvider)
            .screenOpened(
              presetId: presetId,
              mantraName: mantra.localizedName('en'),
              mode: selection.analyticsMode,
              groupId: malaGroupIdFor(
                groups ?? const [],
                selection.groupAccumulatorId,
              ),
              source: widget.source,
            );
      }),
    );
  }

  void _trackSpaceOpened(SpaceMantraItem item) {
    if (_trackedOpened) return;
    _trackedOpened = true;
    ref
        .read(malaAnalyticsProvider)
        .screenOpened(
          presetId: null,
          groupAccumulatorId: item.accumulation.id,
          mantraId: item.mantra.id,
          mantraName: item.title,
          mode: MalaMode.group,
          groupId: item.accumulation.groupId,
          source: widget.source,
        );
  }

  void _switch(List<Mantra> items, int presetCount, int next) {
    if (next < 0 || next >= items.length || next == _index) return;
    // Only preset-to-preset switches are a preset's analytics.
    if (_index < presetCount && next < presetCount) {
      ref
          .read(malaAnalyticsProvider)
          .mantraSwitched(
            fromPresetId: items[_index].presetId,
            toPresetId: items[next].presetId,
            via: MalaSwitchVia.carousel,
          );
    }
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final single = widget.singleAccumulation;
    final singleItem = single == null ? null : SpaceMantraItem.from(single);
    if (singleItem != null) {
      return Scaffold(
        body: ClipRect(
          child: SafeArea(
            child: _buildLoaded(context, const [], [singleItem]),
          ),
        ),
      );
    }

    final catalogue = ref.watch(malaCatalogueProvider);
    // _buildLoaded calls ref.listen, so it must run in this build method.
    final presets = ScreenCacheBuilder.loadedOf(catalogue);
    final loaded =
        presets == null
            ? null
            : _buildLoaded(context, presets, _spaceItems(presets));

    return Scaffold(
      // Clip the page content to its bounds. The bead strand is drawn with an
      // intentional overflow past the arc edges (relied on being clipped); the
      // device-edge clip normally hides it, but during the iOS pop transition
      // the page is composited into a sliding layer where that overflow would
      // otherwise flash onto the incoming screen. This contains it without
      // changing the bead appearance.
      body: ClipRect(
        child: SafeArea(
          child: ScreenCacheBuilder<List<Mantra>>(
            value: catalogue,
            skeleton: const _MalaAppBarScaffold(child: MalaSkeleton()),
            onRetry: () => ref.invalidate(malaCatalogueProvider),
            error:
                (error, retry) => _MalaAppBarScaffold(
                  child: _ErrorView(
                    message:
                        error is Failure
                            ? context.l10n.mala_failed_load_catalogue_error
                            : null,
                    onRetry: retry,
                  ),
                ),
            data: (_) => loaded!,
          ),
        ),
      ),
    );
  }

  /// Joined space accumulations whose mantra is not shown through a preset,
  /// listed after the presets. One whose mantra is its linked preset's is
  /// already reachable from that preset's group switch.
  List<SpaceMantraItem> _spaceItems(List<Mantra> presets) {
    final candidates =
        ref.watch(joinedSpaceMantrasProvider).valueOrNull ??
        const <SpaceMantraItem>[];
    return [
      for (final item in candidates)
        if (resolveGroupAccumulatorPracticeMode(
              item.accumulation,
              catalogue: presets,
            ) ==
            GroupAccumulatorPracticeMode.groupMantra)
          item,
    ];
  }

  Widget _buildLoaded(
    BuildContext context,
    List<Mantra> presets,
    List<SpaceMantraItem> spaces,
  ) {
    final items = [...presets, for (final space in spaces) space.displayMantra];
    if (items.isEmpty) {
      return _MalaAppBarScaffold(
        child: Center(child: Text(context.l10n.mala_no_mantras)),
      );
    }

    if (!_initialisedIndex) {
      _initialisedIndex = true;
      if (widget.initialPresetId != null) {
        final i = presets.indexWhere(
          (m) => m.presetId == widget.initialPresetId,
        );
        if (i >= 0) _index = i;
      }
    }
    _index = _index.clamp(0, items.length - 1);
    final isSpace = _index >= presets.length;
    // Sized for artwork when any mantra has some, so swiping between mantras
    // with and without an image never resizes the layout mid-carousel.
    final hasDeityImage = items.any((m) => m.deityImage != null);

    final language = Localizations.localeOf(context).languageCode;
    final settings = ref.watch(malaSettingsProvider);
    final leftHanded = settings.leftHanded;
    final practice =
        isSpace
            ? _spacePractice(context, spaces[_index - presets.length], settings)
            : _presetPractice(context, presets[_index], settings, language);

    return Column(
      children: [
        _MalaAppBar(
          title: practice.title,
          leftHanded: leftHanded,
          onHandLayoutPressed:
              () => ref
                  .read(malaSettingsProvider.notifier)
                  .setLeftHanded(!leftHanded),
          onMorePressed: practice.onMorePressed,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // When no mantra has artwork the switcher is just the band,
                // centred in a shorter slot so the counter and beads move up.
                Expanded(
                  flex: hasDeityImage ? 48 : 26,
                  child: MantraSwitcher(
                    mantras: items,
                    language: language,
                    tibetanFontFamily: AppConfig.tibetanContentFont,
                    index: _index,
                    speedFactor: settings.mantraSpeed,
                    onIndexChanged:
                        (next) => _switch(items, presets.length, next),
                  ),
                ),
                const SizedBox(height: 16),
                if (practice.showCountSkeleton)
                  MalaCountSkeleton(alignEnd: leftHanded)
                else
                  _CounterBlock(
                    beadInRound: practice.displayTotal % practice.beadsPerRound,
                    beadsPerRound: practice.beadsPerRound,
                    rounds: practice.displayTotal ~/ practice.beadsPerRound,
                    leftHanded: leftHanded,
                    addRounds: practice.addRounds,
                  ),
                const SizedBox(height: 8),
                Expanded(
                  flex: hasDeityImage ? 30 : 42,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final retry = practice.onSeedRetry;
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: constraints.maxHeight * 0.85,
                          width: double.infinity,
                          child:
                              retry != null
                                  ? _ErrorView(
                                    message:
                                        context.l10n.mala_count_load_error,
                                    onRetry: retry,
                                  )
                                  : MalaBeads(
                                    key: ValueKey(practice.beadsKey),
                                    total: practice.displayTotal,
                                    beadInRound:
                                        practice.displayTotal %
                                        practice.beadsPerRound,
                                    beadsPerRound: practice.beadsPerRound,
                                    enabled: practice.countingEnabled,
                                    mirrored: leftHanded,
                                    beadImageBytes: practice.beadImageBytes,
                                    beadColor: const Color(0xFF8D6E63),
                                    threadColor: const Color(0xFFC62828),
                                    onTap:
                                        () => practice.onBead(MalaInput.tap),
                                    onSwipe:
                                        () => practice.onBead(MalaInput.swipe),
                                  ),
                        ),
                      );
                    },
                  ),
                ),
                if (practice.footer != null) ...[
                  const SizedBox(height: 12),
                  practice.footer!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  _MalaPractice _presetPractice(
    BuildContext context,
    Mantra mantra,
    MalaSettingsState settings,
    String language,
  ) {
    ref.watch(
      prefetchBookmarkExistsProvider(
        BookmarkTarget(type: BookmarkType.accumulator, sourceId: mantra.presetId),
      ),
    );

    final counter = ref.watch(malaCounterProvider(mantra));
    final notifier = ref.read(malaCounterProvider(mantra).notifier);
    final selection = ref.watch(
      malaAccumulationSelectionProvider(mantra.presetId),
    );
    final groupsAsync = ref.watch(
      joinedAccumulatorGroupsProvider(mantra.presetId),
    );
    final groups = groupsAsync.valueOrNull ?? const <AccumulatorGroup>[];
    ref.watch(groupAccumulationCountsProvider(mantra.presetId));
    ref.watch(joinedGroupUserCountsProvider(mantra.presetId));
    final groupCountsNotifier = ref.read(
      groupAccumulationCountsProvider(mantra.presetId).notifier,
    );

    _applyInitialGroupSelectionIfNeeded(mantra.presetId);
    _trackOpened(mantra);

    ref.listen(joinedAccumulatorGroupsProvider(mantra.presetId), (_, next) {
      next.whenData((loadedGroups) {
        ref
            .read(malaAccumulationSelectionProvider(mantra.presetId).notifier)
            .validateAgainst(
              loadedGroups,
              keepEndedId:
                  widget.openedFromEndedAccumulator
                      ? widget.initialGroupAccumulatorId
                      : null,
            );
        ref.invalidate(joinedGroupUserCountsProvider(mantra.presetId));
      });
    });

    ref.listen(joinedGroupUserCountsProvider(mantra.presetId), (_, next) {
      next.whenData(groupCountsNotifier.mergeFromServerCounts);
    });

    final groupId = selection.groupAccumulatorId;
    final showCountSkeleton = counter.isSeeding && !counter.seedFailed;
    // While seeding, keep beads at 0 so a stale Hive total does not light the arc.
    final displayTotal =
        showCountSkeleton
            ? 0
            : groupId == null
            ? counter.total
            : groupCountsNotifier.countFor(groupId);
    final beadsPerRound = counter.beadsPerRound;
    final countingEnabled =
        !counter.isSeeding &&
        (selection.isPersonal || selection.groupAccumulatorId != null);

    void onBead(MalaInput input) {
      if (counter.isSeeding) return;
      final int? total;
      if (selection.isPersonal) {
        total = notifier.incrementBead(
          soundEnabled: settings.soundEnabled,
          vibrationEnabled: settings.vibrationEnabled,
        );
      } else {
        final selectedGroupId = selection.groupAccumulatorId;
        if (selectedGroupId == null || groups.isEmpty) return;
        total = groupCountsNotifier.increment(
          groupAccumulatorId: selectedGroupId,
          groups: groups,
          soundEnabled: settings.soundEnabled,
          vibrationEnabled: settings.vibrationEnabled,
          beadsPerRound: beadsPerRound,
        );
      }
      // Null means the tap was ignored, so no bead was counted.
      if (total == null) return;
      _session.onBead(
        presetId: mantra.presetId,
        mantraName: mantra.localizedName('en'),
        mode: selection.analyticsMode,
        groupId: malaGroupIdFor(groups, selection.groupAccumulatorId),
        total: total,
        roundComplete: total % beadsPerRound == 0,
        input: input,
      );
    }

    return _MalaPractice(
      title: mantra.displayTitle(language),
      onMorePressed: () => MalaSettingsSheet.show(context, mantra: mantra),
      showCountSkeleton: showCountSkeleton,
      displayTotal: displayTotal,
      beadsPerRound: beadsPerRound,
      countingEnabled: countingEnabled,
      beadImageBytes: counter.beadImageBytes,
      beadsKey:
          '${mantra.presetId}_${selection.groupAccumulatorId ?? 'personal'}',
      onBead: onBead,
      onSeedRetry: counter.seedFailed ? notifier.seed : null,
      addRounds:
          widget.openedFromEndedAccumulator
              ? null
              : AddMalaRoundsButton(mantra: mantra, size: 32),
      footer:
          widget.openedFromEndedAccumulator
              ? null
              : GroupAccumulationsBar(
                mantra: mantra,
                presetTitle: mantra.displayTitle(language),
              ),
    );
  }

  /// A group accumulation's own mantra: counted only into it, with no
  /// personal-or-group switch, bookmark, share or add-to-practice.
  _MalaPractice _spacePractice(
    BuildContext context,
    SpaceMantraItem item,
    MalaSettingsState settings,
  ) {
    final accumulatorId = item.accumulation.id;
    ref.watch(groupAccumulationCountsProvider(item.countsKey));
    final counts = ref.read(
      groupAccumulationCountsProvider(item.countsKey).notifier,
    );
    final seeding = ref.watch(groupMantraCountSeedProvider(accumulatorId))
        .isLoading;
    _trackSpaceOpened(item);

    const beadsPerRound = kBeadsPerRound;
    final displayTotal = seeding ? 0 : counts.countFor(accumulatorId);

    void onBead(MalaInput input) {
      if (seeding) return;
      final total = counts.increment(
        groupAccumulatorId: accumulatorId,
        groups: const [],
        soundEnabled: settings.soundEnabled,
        vibrationEnabled: settings.vibrationEnabled,
        beadsPerRound: beadsPerRound,
      );
      // Null means the tap was ignored, so no bead was counted.
      if (total == null) return;
      _session.onBead(
        presetId: null,
        groupAccumulatorId: accumulatorId,
        mantraId: item.mantra.id,
        mantraName: item.title,
        mode: MalaMode.group,
        groupId: item.accumulation.groupId,
        total: total,
        roundComplete: total % beadsPerRound == 0,
        input: input,
      );
    }

    return _MalaPractice(
      title: item.title,
      onMorePressed: () => MalaPracticeSettingsSheet.show(context),
      showCountSkeleton: seeding,
      displayTotal: displayTotal,
      beadsPerRound: beadsPerRound,
      countingEnabled: !seeding,
      beadImageBytes: watchSpaceMantraBeadBytes(ref, item),
      beadsKey: item.countsKey,
      onBead: onBead,
    );
  }

  void _applyInitialGroupSelectionIfNeeded(String presetId) {
    final groupId = widget.initialGroupAccumulatorId;
    if (groupId == null || groupId.isEmpty || _appliedInitialGroupSelection) {
      return;
    }
    _appliedInitialGroupSelection = true;
    ref
        .read(malaAccumulationSelectionProvider(presetId).notifier)
        .applyNavigationIntent(groupId);
  }
}

/// Bead count over a rounds row (`n` + mala icon + optional add button).
/// Left-aligned for the right-hand layout, right-aligned for the left hand.
class _CounterBlock extends StatelessWidget {
  const _CounterBlock({
    required this.beadInRound,
    required this.beadsPerRound,
    required this.rounds,
    required this.leftHanded,
    this.addRounds,
  });

  final int beadInRound;
  final int beadsPerRound;
  final int rounds;
  final bool leftHanded;
  final Widget? addRounds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final useTibetan = context.isTibetanLocale;
    final beadText =
        useTibetan ? toTibetanDigits(beadInRound) : '$beadInRound';
    final perRoundText =
        useTibetan ? toTibetanDigits(beadsPerRound) : '$beadsPerRound';
    final roundsText = useTibetan ? toTibetanDigits(rounds) : '$rounds';
    final roundsLabel =
        useTibetan
            ? toTibetanDigits(l10n.mala_rounds_count(rounds))
            : l10n.mala_rounds_count(rounds);
    final color = theme.colorScheme.onSurface;
    final mutedColor = color.withValues(alpha: 0.7);
    final beadStyle = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: color,
    );
    final perRoundStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: color,
    );
    final roundsStyle = theme.textTheme.titleLarge?.copyWith(
      color: mutedColor,
    );

    return Semantics(
      label: l10n.mala_counter_semantics(
        beadInRound,
        beadsPerRound,
        roundsLabel,
      ),
      child: Column(
        crossAxisAlignment:
            leftHanded ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: beadText,
              style: beadStyle,
              children: [TextSpan(text: '/$perRoundText', style: perRoundStyle)],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(roundsText, style: roundsStyle),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: Image.asset(
                  AppAssets.homeMalaIcon,
                  width: 22,
                  height: 22,
                  color: mutedColor,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              if (addRounds != null) ...[
                const SizedBox(width: 10),
                addRounds!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// App bar with a back button, the mantra name, the hand-layout toggle and
/// the settings menu.
class _MalaAppBar extends StatelessWidget {
  const _MalaAppBar({
    required this.title,
    this.leftHanded = false,
    this.onHandLayoutPressed,
    this.onMorePressed,
  });
  final String title;
  final bool leftHanded;
  final VoidCallback? onHandLayoutPressed;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppAssets.arrowLeft),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            icon: _HandLayoutIcon(leftHanded: leftHanded),
            tooltip: context.l10n.mala_hand_layout_tooltip,
            onPressed: onHandLayoutPressed,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 24),
            onPressed: onMorePressed,
          ),
        ],
      ),
    );
  }
}

/// Two mirrored triangles; the solid one marks the active hand.
class _HandLayoutIcon extends StatelessWidget {
  const _HandLayoutIcon({required this.leftHanded});

  final bool leftHanded;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(24),
      painter: _HandLayoutIconPainter(
        fillLeft: leftHanded,
        color: IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _HandLayoutIconPainter extends CustomPainter {
  const _HandLayoutIconPainter({required this.fillLeft, required this.color});

  final bool fillLeft;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    // Right-angle triangles with their vertical edge at the centre and the
    // hypotenuse running down to the outer bottom corner.
    final left =
        Path()
          ..moveTo(10 * s, 3 * s)
          ..lineTo(10 * s, 21 * s)
          ..lineTo(2 * s, 21 * s)
          ..close();
    final right =
        Path()
          ..moveTo(14 * s, 3 * s)
          ..lineTo(14 * s, 21 * s)
          ..lineTo(22 * s, 21 * s)
          ..close();
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeJoin = StrokeJoin.round;
    final fill =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
    canvas.drawPath(fillLeft ? left : right, fill);
  }

  @override
  bool shouldRepaint(covariant _HandLayoutIconPainter old) =>
      old.fillLeft != fillLeft || old.color != color;
}

/// Wraps non-loaded states with a minimal back-button app bar.
class _MalaAppBarScaffold extends StatelessWidget {
  const _MalaAppBarScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message ?? context.l10n.something_went_wrong),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}
