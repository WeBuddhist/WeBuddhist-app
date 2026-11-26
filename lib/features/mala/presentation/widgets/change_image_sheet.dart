import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/responsive_cover_image.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_image_option.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_appearance_provider.dart';
import 'package:flutter_pecha/features/mala/presentation/widgets/mala_sheet_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The mantra's deity gallery (`GET /mantras/{id}/images`). "Use" saves the
/// pick on the server; "Restore default" (enabled only while the user has a
/// pick) goes back to the mantra's default. Closes with `true` when the image
/// changed; a failed save shows an error toast and keeps the sheet open.
class ChangeImageSheet extends ConsumerStatefulWidget {
  const ChangeImageSheet({super.key, required this.mantraId});

  /// The mantra whose image is changed.
  final String mantraId;

  static Future<bool?> show(BuildContext context, {required String mantraId}) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder:
          (_) => FractionallySizedBox(
            heightFactor: 0.85,
            child: MalaSheetToastHost(
              child: ChangeImageSheet(mantraId: mantraId),
            ),
          ),
    );
  }

  @override
  ConsumerState<ChangeImageSheet> createState() => _ChangeImageSheetState();
}

class _ChangeImageSheetState extends ConsumerState<ChangeImageSheet> {
  /// The tapped option id; null until the user taps one.
  String? _picked;
  bool _saving = false;

  /// The user's saved pick; null means the default.
  String? get _savedPick =>
      ref
          .read(malaAppearanceProvider(widget.mantraId))
          .valueOrNull
          ?.deityImageId;

  /// The id that is ticked before any tap: the user's pick, else the
  /// mantra's default.
  String? _currentId(List<MalaImageOption> options) {
    final saved = _savedPick;
    if (saved != null) return saved;
    for (final option in options) {
      if (option.isDefault) return option.id;
    }
    return null;
  }

  Future<void> _use(List<MalaImageOption> options) async {
    final picked = _picked;
    if (picked == null || picked == _currentId(options)) {
      Navigator.of(context).pop(false);
      return;
    }
    // Picking the default saves no pick, so the user keeps following it.
    final isDefault = options.any((o) => o.id == picked && o.isDefault);
    await _save(isDefault ? null : picked);
  }

  Future<void> _save(String? imageId) async {
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final saved = await ref
        .read(malaAppearanceProvider(widget.mantraId).notifier)
        .setDeityImage(imageId);
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
    final hasPick = appearance.valueOrNull?.deityImageId != null;
    final optionsAsync = ref.watch(malaDeityImagesProvider(widget.mantraId));
    final options = optionsAsync.valueOrNull;
    final canUse =
        options != null &&
        options.isNotEmpty &&
        (appearance.hasValue || appearance.hasError);

    final Widget body;
    if (options != null && options.isNotEmpty) {
      final selected = _picked ?? _currentId(options);
      body = GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 0.8,
        ),
        itemCount: options.length,
        itemBuilder: (context, i) {
          final option = options[i];
          return _ImageTile(
            key: ValueKey('mala-image-${option.id}'),
            option: option,
            selected: option.id == selected,
            onTap: () => setState(() => _picked = option.id),
          );
        },
      );
    } else if (optionsAsync.hasError) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.mala_images_load_error),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  () =>
                      ref.invalidate(malaDeityImagesProvider(widget.mantraId)),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    } else if (optionsAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Center(child: Text(l10n.mala_images_empty));
    }

    return MalaSheetFrame(
      title: l10n.mala_change_image,
      expand: true,
      trailing: TextButton(
        onPressed: hasPick && !_saving ? () => _save(null) : null,
        child: Text(l10n.mala_restore_default_image),
      ),
      footer: MalaPrimaryButton(
        label: l10n.mala_use_image,
        busy: _saving,
        onPressed: canUse ? () => _use(options) : null,
      ),
      child: body,
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MalaImageOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        // The whole tile, even while its image is loading or missing.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ResponsiveCoverImage(image: option.image, fit: BoxFit.cover),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.blue, width: 2),
                ),
              ),
            if (selected)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    AppAssets.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
