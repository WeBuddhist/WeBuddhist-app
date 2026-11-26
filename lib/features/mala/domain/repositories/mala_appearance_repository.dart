import 'package:flutter_pecha/features/mala/domain/entities/mala_image_option.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mala_skin.dart';
import 'package:flutter_pecha/features/mala/domain/entities/mantra_appearance.dart';

/// A change to one field of a [MantraAppearance]. [id] null restores the
/// default; leaving the whole change out keeps the field as it is.
typedef AppearancePick = ({String? id});

/// The user's per-mantra deity image and bead skin, and the choices offered.
/// Every call throws on failure.
abstract class MalaAppearanceRepository {
  /// The mantra's deity gallery, in display order.
  Future<List<MalaImageOption>> deityImages(String mantraId);

  /// Bead skins the user can pick.
  Future<List<MalaSkin>> skins();

  Future<MantraAppearance> appearance(String mantraId);

  /// Saves [deityImage] and/or [malaSkin]; returns the updated appearance.
  Future<MantraAppearance> updateAppearance(
    String mantraId, {
    AppearancePick? deityImage,
    AppearancePick? malaSkin,
  });
}
