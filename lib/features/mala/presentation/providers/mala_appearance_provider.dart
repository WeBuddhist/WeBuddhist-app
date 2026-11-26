import 'dart:typed_data';

import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_image_option.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra_appearance.dart';
import 'package:flutter_pecha/features/mala/domain/repositories/mala_appearance_repository.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/mala_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/providers/space_mantra_providers.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';
import 'package:flutter_pecha/features/more/presentation/providers/mantra_counts_provider.dart';
import 'package:flutter_pecha/shared/domain/value_objects/responsive_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('MalaAppearance');

/// The user's deity image and bead skin for one mantra, keyed by mantra id.
///
/// Read from the server while something shows the mantra. Saving updates the
/// state from the PATCH response, so the mala screen changes at once, then
/// refreshes the lists that carry the choice elsewhere.
class MalaAppearanceNotifier
    extends AutoDisposeFamilyAsyncNotifier<MantraAppearance, String> {
  MalaAppearanceRepository get _repository =>
      ref.read(malaAppearanceRepositoryProvider);

  @override
  Future<MantraAppearance> build(String mantraId) =>
      ref.watch(malaAppearanceRepositoryProvider).appearance(mantraId);

  /// [imageId] null restores the mantra's default. False when the save
  /// failed; nothing changed then.
  Future<bool> setDeityImage(String? imageId) =>
      _save(deityImage: (id: imageId));

  /// [skinId] null restores the default bead. False when the save failed.
  Future<bool> setMalaSkin(String? skinId) => _save(malaSkin: (id: skinId));

  Future<bool> _save({
    AppearancePick? deityImage,
    AppearancePick? malaSkin,
  }) async {
    final analytics = ref.read(malaAnalyticsProvider);
    try {
      final updated = await _repository.updateAppearance(
        arg,
        deityImage: deityImage,
        malaSkin: malaSkin,
      );
      state = AsyncData(updated);
      if (deityImage != null) {
        analytics.settingChanged(
          setting: MalaSetting.deityImage,
          value: deityImage.id,
          presetId: arg,
        );
      }
      if (malaSkin != null) {
        analytics.settingChanged(
          setting: MalaSetting.skin,
          value: malaSkin.id,
          presetId: arg,
        );
      }
      // Other lists carry the choice too; refresh them in the background.
      ref.invalidate(mantraCountsProvider);
      ref.invalidate(joinedSpaceMantrasProvider);
      return true;
    } catch (e, stack) {
      _logger.error('Saving the appearance of mantra $arg failed', e, stack);
      return false;
    }
  }
}

final malaAppearanceProvider = AsyncNotifierProvider.autoDispose
    .family<MalaAppearanceNotifier, MantraAppearance, String>(
      MalaAppearanceNotifier.new,
    );

/// A mantra's deity gallery, for the Change image sheet. Fetched each time
/// the sheet opens, since the image URLs expire.
final malaDeityImagesProvider = FutureProvider.autoDispose
    .family<List<MalaImageOption>, String>((ref, mantraId) {
      return ref.watch(malaAppearanceRepositoryProvider).deityImages(mantraId);
    });

/// Bead skins offered in the Bead style sheet (`GET /mala-skins`).
final malaSkinsProvider = FutureProvider.autoDispose<List<MalaSkin>>((ref) {
  return ref.watch(malaAppearanceRepositoryProvider).skins();
});

/// Bead artwork for the mantra [mantraId]: the skin the appearance resolves
/// (the user's pick, else the mantra's default). [ownBytes], the bead the
/// accumulation already holds, only stands in while that loads or when it
/// fails: it can still be an earlier pick, so it is never taken as the
/// default once the appearance is known.
Uint8List? watchMalaBeadBytes(
  WidgetRef ref,
  String? mantraId,
  Uint8List? ownBytes,
) {
  if (mantraId == null) return ownBytes;
  final appearance = ref.watch(malaAppearanceProvider(mantraId)).valueOrNull;
  final url = appearance?.malaSkinUrl;
  if (url == null) return ownBytes;
  return ref.watch(malaBeadImageBytesProvider(url)).valueOrNull ?? ownBytes;
}

/// The artwork shown above [mantra]: the image the appearance resolves (the
/// user's pick, else the mantra's default), or the mantra's own until then.
ResponsiveImage? watchMalaMantraImage(WidgetRef ref, Mantra mantra) {
  final mantraId = mantra.mantraId;
  if (mantraId == null) return mantra.deityImage;
  final appearance = ref.watch(malaAppearanceProvider(mantraId)).valueOrNull;
  return appearance?.deityImage ?? mantra.deityImage;
}
