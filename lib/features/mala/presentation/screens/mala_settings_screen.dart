import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pecha/core/analytics/share_analytics.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/deep_linking/deep_link_url_builder.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/network/connectivity_service.dart'
    show connectivityNotifierProvider;
import 'package:flutter_pecha/core/services/share_url/share_url_service.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/destructive_confirmation_dialog.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_accumulator_providers.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/accumulator_groups_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/group_accumulation_counts_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_accumulation_selection_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_appearance_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_settings_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/space_mantra_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/bead_style_sheet.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/change_image_sheet.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_beads.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mantra_animation_sheet.dart';
import 'package:flutter_pecha/features/practice/data/datasource/bookmark_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/presentation/controllers/bookmark_controller.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/bookmark_providers.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_pecha/shared/widgets/app_toggle_switch.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// Why Mala settings closed, so the mala screen can confirm the change.
enum MalaSettingsOutcome { beadStyleUpdated, imageUpdated }

/// Full-page Mala settings, opened from the ⋮ on the mala screen.
///
/// Sections: Practice (mantra animation, sound, vibration, reset count),
/// Appearance (bead style, change image) and Save & share. For a preset
/// counted personally, "Add to my practices" sits at the top and Bookmark
/// shows under Save & share. A group accumulation's own mantra ([space]) has
/// no preset, so it gets only Practice (without reset) and Appearance.
/// Appearance is saved per mantra on the server, so it is hidden when the
/// mantra has no id.
class MalaSettingsScreen extends ConsumerWidget {
  const MalaSettingsScreen({super.key, required this.mantra, this.space});

  /// The preset, or [SpaceMantraItem.displayMantra] for a space mantra. Its
  /// [Mantra.mantraId] keys the appearance.
  final Mantra mantra;

  /// Set for a group accumulation's own mantra.
  final SpaceMantraItem? space;

  bool get _isPreset => space == null;

  static Future<MalaSettingsOutcome?> show(
    BuildContext context, {
    required Mantra mantra,
    SpaceMantraItem? space,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<MalaSettingsOutcome>(
        settings: const RouteSettings(name: 'mala-settings'),
        builder: (_) => MalaSettingsScreen(mantra: mantra, space: space),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(malaSettingsProvider);
    final settingsNotifier = ref.read(malaSettingsProvider.notifier);
    final space = this.space;
    final mantraId = mantra.mantraId;
    final ownBeadBytes =
        space == null
            ? ref.watch(malaCounterProvider(mantra)).beadImageBytes
            : watchSpaceMantraBeadBytes(ref, space);

    final isPersonal =
        _isPreset &&
        ref
            .watch(malaAccumulationSelectionProvider(mantra.presetId))
            .isPersonal;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: l10n.mala_settings_section),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (isPersonal) ...[
                    _SettingsTile(
                      icon: const Icon(AppAssets.plus, size: 22),
                      label: l10n.mala_add_to_practice,
                      onTap: () => _onAddToPractice(context),
                    ),
                    const _TileDivider(),
                  ],
                  _SectionHeader(label: l10n.mala_section_practice),
                  _SettingsTile(
                    icon: const Icon(AppAssets.speedometer, size: 22),
                    label: l10n.mala_mantra_animation,
                    value:
                        settings.playAnimation
                            ? MantraAnimationSheet.speedLabel(
                              context,
                              settings.mantraSpeed,
                            )
                            : l10n.mala_animation_off,
                    showChevron: true,
                    onTap: () => MantraAnimationSheet.show(context),
                  ),
                  const _TileDivider(),
                  _ToggleTile(
                    icon: AppAssets.speakerSimpleHigh,
                    label: l10n.mala_sound,
                    value: settings.soundEnabled,
                    onChanged: settingsNotifier.setSoundEnabled,
                  ),
                  const _TileDivider(),
                  _ToggleTile(
                    icon: AppAssets.vibrate,
                    label: l10n.mala_vibration,
                    value: settings.vibrationEnabled,
                    onChanged: settingsNotifier.setVibrationEnabled,
                  ),
                  if (_isPreset) ...[
                    const _TileDivider(),
                    _ResetCountTile(mantra: mantra),
                  ],
                  if (mantraId != null) ...[
                    _SectionHeader(label: l10n.mala_section_appearance),
                    _BeadStyleTile(
                      mantraId: mantraId,
                      ownBeadBytes: ownBeadBytes,
                      onTap:
                          () => _onBeadStyle(context, mantraId, ownBeadBytes),
                    ),
                    const _TileDivider(),
                    _SettingsTile(
                      icon: const Icon(AppAssets.pencilSimple, size: 22),
                      label: l10n.mala_change_image,
                      showChevron: true,
                      onTap: () => _onChangeImage(context, mantraId),
                    ),
                  ],
                  if (_isPreset) ...[
                    _SectionHeader(label: l10n.mala_section_save_share),
                    if (isPersonal) ...[
                      _BookmarkTile(mantra: mantra),
                      const _TileDivider(),
                    ],
                    _SettingsTile(
                      icon: const Icon(AppAssets.readerShare, size: 22),
                      label: l10n.share,
                      onTap: () => _onShare(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onBeadStyle(
    BuildContext context,
    String mantraId,
    Uint8List? ownBeadBytes,
  ) async {
    final changed = await BeadStyleSheet.show(
      context,
      mantraId: mantraId,
      ownBeadBytes: ownBeadBytes,
    );
    if (changed == true && context.mounted) {
      Navigator.of(context).pop(MalaSettingsOutcome.beadStyleUpdated);
    }
  }

  Future<void> _onChangeImage(BuildContext context, String mantraId) async {
    final changed = await ChangeImageSheet.show(context, mantraId: mantraId);
    if (changed == true && context.mounted) {
      Navigator.of(context).pop(MalaSettingsOutcome.imageUpdated);
    }
  }

  void _onAddToPractice(BuildContext context) {
    // Mala is login-gated, so the user is always authenticated here; the
    // edit-routine route's auth guard is a backstop. Capture the router before
    // leaving settings, then open the routine editor with the mala injected
    // as an ACCUMULATOR session.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.pushNamed('edit-routine', extra: {'initialMantra': mantra});
  }

  Future<void> _onShare(BuildContext context) async {
    final shareMessage = context.l10n.share_mala_message;
    final sharePositionOrigin = getSharePositionOrigin(context: context);
    // Read before any await: the page may be closed while sharing.
    final shareAnalytics = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(shareAnalyticsProvider);
    final longUrl =
        DeepLinkUrlBuilder.malaLink(presetId: mantra.presetId).toString();
    final shareUrl = await resolveShareUrl(context, longUrl);
    if (!context.mounted) return;

    final result = await SharePlus.instance.share(
      ShareParams(
        text: '$shareMessage\n\n$shareUrl',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    if (ShareAnalytics.wasUsed(result)) {
      shareAnalytics.contentShared(
        surface: ShareSurface.mala,
        targetId: mantra.presetId,
        format: 'text',
      );
    }
  }
}

/// Bead style row: the bead shown now and the name of the user's skin.
class _BeadStyleTile extends ConsumerWidget {
  const _BeadStyleTile({
    required this.mantraId,
    required this.ownBeadBytes,
    required this.onTap,
  });

  final String mantraId;
  final Uint8List? ownBeadBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pick =
        ref.watch(malaAppearanceProvider(mantraId)).valueOrNull?.malaSkinId;
    String? skinName;
    if (pick != null) {
      final skins = ref.watch(malaSkinsProvider).valueOrNull;
      for (final skin in skins ?? const <MalaSkin>[]) {
        if (skin.id == pick) skinName = skin.displayName;
      }
    }
    return _SettingsTile(
      icon: MalaBeadPreview(
        imageBytes: watchMalaBeadBytes(ref, mantraId, ownBeadBytes),
        size: 22,
      ),
      label: l10n.mala_bead_style,
      // A pick whose name has not loaded shows no value rather than Default.
      value: pick == null ? l10n.mala_bead_default : skinName,
      showChevron: true,
      onTap: onTap,
    );
  }
}

class _BookmarkTile extends ConsumerWidget {
  const _BookmarkTile({required this.mantra});

  final Mantra mantra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isBookmarked = ref.watch(
      isBookmarkedProvider(
        BookmarkTarget(
          type: BookmarkType.accumulator,
          sourceId: mantra.presetId,
        ),
      ),
    );
    return _SettingsTile(
      icon: Icon(
        isBookmarked ? AppAssets.bookmarkSimpleFill : AppAssets.bookmarkSimple,
        size: 22,
      ),
      label: isBookmarked ? l10n.mala_bookmarked : l10n.mala_add_to_bookmark,
      onTap: () {
        final language = ref.read(contentLanguageProvider);
        BookmarkController(
          ref: ref,
          context: context,
        ).toggleMala(mantra.presetId, name: mantra.displayTitle(language));
      },
    );
  }
}

/// Resets the active session (personal or the selected group) after a
/// confirmation, then returns to the mala screen.
class _ResetCountTile extends ConsumerWidget {
  const _ResetCountTile({required this.mantra});

  final Mantra mantra;

  static const _destructive = Color(0xFFB03027);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityNotifierProvider);
    final selection = ref.watch(
      malaAccumulationSelectionProvider(mantra.presetId),
    );
    final counter = ref.watch(malaCounterProvider(mantra));
    final canReset =
        isOnline &&
        !counter.isSeeding &&
        !counter.isResetting &&
        (selection.isPersonal || selection.groupAccumulatorId != null);

    return _SettingsTile(
      icon: const Icon(
        AppAssets.arrowCounterClockwise,
        size: 22,
        color: _destructive,
      ),
      label: context.l10n.mala_reset_count,
      labelColor: _destructive,
      enabled: canReset,
      onTap: () => _onReset(context, ref),
    );
  }

  Future<void> _onReset(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final selection = ref.read(
      malaAccumulationSelectionProvider(mantra.presetId),
    );
    final analytics = ref.read(malaAnalyticsProvider);

    final result = await showDestructiveConfirmationDialog(
      context,
      title: l10n.mala_reset_title,
      message: l10n.mala_reset_count_confirm,
      confirmLabel: l10n.mala_reset_confirm,
      cancelLabel: l10n.cancel,
      barrierDismissible: false,
      onConfirmed: () async {
        HapticFeedback.mediumImpact();
        if (selection.isPersonal) {
          return ref.read(malaCounterProvider(mantra).notifier).resetCount();
        }
        final groupAccumulatorId = selection.groupAccumulatorId;
        if (groupAccumulatorId == null) return false;
        return ref
            .read(groupAccumulationCountsProvider(mantra.presetId).notifier)
            .resetCount(groupAccumulatorId: groupAccumulatorId);
      },
    );
    if (result == true) {
      analytics.countReset(
        presetId: mantra.presetId,
        groupAccumulatorId:
            selection.isPersonal ? null : selection.groupAccumulatorId,
      );
    }
    if (!context.mounted) return;
    if (result == true) {
      if (!selection.isPersonal) {
        final groupId = selection.groupAccumulatorId;
        if (groupId != null) {
          ref.invalidate(groupAccumulatorDetailProvider(groupId));
        }
        // Refresh session counts from detail API; post-reset guard prevents stale totals.
        ref.invalidate(joinedGroupUserCountsProvider(mantra.presetId));
        // Refresh lifetime totals for the accumulations sheet.
        ref.invalidate(joinedAccumulatorGroupsProvider(mantra.presetId));
      }
      Navigator.of(context).pop();
    } else if (result == false) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.something_went_wrong)),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppAssets.arrowLeft),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          // Balances the back button so the title stays centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: isDark ? AppColors.cardBorderDark : AppColors.grey300,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.showChevron = false,
    this.labelColor,
    this.enabled = true,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  /// Current value shown muted before the chevron (e.g. "1x", "Default").
  final String? value;
  final bool showChevron;
  final Color? labelColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final foreground = labelColor ?? onSurface;
    final muted = onSurface.withValues(alpha: 0.55);

    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: foreground),
                  child: SizedBox.square(
                    dimension: 24,
                    child: Center(child: icon),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  Icon(AppAssets.caretRight, size: 16, color: muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 24,
            child: Icon(icon, size: 22, color: foreground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
