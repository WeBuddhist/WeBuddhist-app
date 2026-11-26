import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/shared/domain/value_objects/responsive_image.dart';

/// The user's deity image and bead skin for one mantra
/// (`GET/PATCH /users/me/mantras/{id}/appearance`). Saved on the server, so
/// it follows the user to every accumulation of the mantra and every device.
class MantraAppearance extends Equatable {
  const MantraAppearance({
    required this.mantraId,
    this.deityImageId,
    this.malaSkinId,
    this.deityImage,
    this.malaSkinUrl,
  });

  final String mantraId;

  /// The user's deity image pick; null means the mantra's default.
  final String? deityImageId;

  /// The user's bead skin pick; null means the default.
  final String? malaSkinId;

  /// The deity image to show: the pick, else the default.
  final ResponsiveImage? deityImage;

  /// The bead skin to show: the pick, else the mantra's default.
  final String? malaSkinUrl;

  @override
  List<Object?> get props => [
    mantraId,
    deityImageId,
    malaSkinId,
    deityImage,
    malaSkinUrl,
  ];
}
