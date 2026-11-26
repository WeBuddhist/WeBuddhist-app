import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_appearance_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_beads.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_sheet_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Grid of bead skins (`GET /mala-skins`) for one mantra. The first tile is
/// the default bead. "Use this style" saves the pick on the server and closes
/// the sheet with `true` when it changed anything; a failed save shows an
/// error toast and keeps the sheet open.
class BeadStyleSheet extends ConsumerStatefulWidget {
  const BeadStyleSheet({
    super.key,
    required this.mantraId,
    required this.ownBeadBytes,
  });

  /// The mantra whose bead is changed.
  final String mantraId;

  /// The bead the accumulation shows without a pick, for the Default tile.
  final Uint8List? ownBeadBytes;

  static Future<bool?> show(
    BuildContext context, {
    required String mantraId,
    required Uint8List? ownBeadBytes,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder:
          (_) => FractionallySizedBox(
            heightFactor: 0.62,
            child: MalaSheetToastHost(
              child: BeadStyleSheet(
                mantraId: mantraId,
                ownBeadBytes: ownBeadBytes,
              ),
            ),
          ),
    );
  }

  @override
  ConsumerState<BeadStyleSheet> createState() => _BeadStyleSheetState();
}

class _BeadStyleSheetState extends ConsumerState<BeadStyleSheet> {
  /// The tapped tile: a skin id, or null for Default. Unset until a tap.
  ({String? id})? _picked;
  bool _saving = false;

  /// The saved pick; null is Default.
  String? get _current =>
      ref.read(malaAppearanceProvider(widget.mantraId)).valueOrNull?.malaSkinId;

  Future<void> _use() async {
    final navigator = Navigator.of(context);
    final picked = _picked;
    if (picked == null || picked.id == _current) {
      navigator.pop(false);
      return;
    }
    setState(() => _saving = true);
    final saved = await ref
        .read(malaAppearanceProvider(widget.mantraId).notifier)
        .setMalaSkin(picked.id);
    if (!mounted) return;
    if (saved) {
      navigator.pop(true);
      return;
    }
    setState(() => _saving = false);
    showMalaToast(
      context,
      context.l10n.mala_appearance_save_failed,
      isError: true,
      bottomMargin: 80,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appearance = ref.watch(malaAppearanceProvider(widget.mantraId));
    final skinsAsync = ref.watch(malaSkinsProvider);
    final skins = skinsAsync.valueOrNull;
    final selected = (_picked ?? (id: appearance.valueOrNull?.malaSkinId)).id;

    final Widget body;
    if (skins != null) {
      body = GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          _BeadTile(
            key: const ValueKey('mala-skin-default'),
            label: l10n.mala_bead_default,
            selected: selected == null,
            onTap: () => setState(() => _picked = (id: null)),
            bead: MalaBeadPreview(imageBytes: widget.ownBeadBytes),
          ),
          for (final skin in skins)
            _BeadTile(
              key: ValueKey('mala-skin-${skin.id}'),
              label: skin.displayName,
              selected: selected == skin.id,
              onTap: () => setState(() => _picked = (id: skin.id)),
              bead: _SkinPreview(skin: skin),
            ),
        ],
      );
    } else if (skinsAsync.hasError) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.mala_beads_load_error),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(malaSkinsProvider),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return MalaSheetFrame(
      title: l10n.mala_bead_style,
      expand: true,
      footer: MalaPrimaryButton(
        label: l10n.mala_use_this_style,
        busy: _saving,
        // Wait for the saved pick, so an unchanged pick is never re-sent.
        onPressed: appearance.hasValue || appearance.hasError ? _use : null,
      ),
      child: body,
    );
  }
}

/// A server skin drawn like a bead on the strand.
class _SkinPreview extends ConsumerWidget {
  const _SkinPreview({required this.skin});

  final MalaSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MalaBeadPreview(
      imageBytes: ref.watch(malaBeadImageBytesProvider(skin.url)).valueOrNull,
    );
  }
}

class _BeadTile extends StatelessWidget {
  const _BeadTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.bead,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget bead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark ? AppColors.surfaceDark : AppColors.surfaceWhite;
    final border =
        selected
            ? BorderSide(color: theme.colorScheme.onSurface, width: 2)
            : BorderSide(
              color: isDark ? AppColors.cardBorderDark : AppColors.grey300,
            );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(child: ExcludeSemantics(child: bead)),
        ),
      ),
    );
  }
}
