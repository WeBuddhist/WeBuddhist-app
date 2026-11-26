import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/shared/domain/value_objects/responsive_image.dart';

/// One deity image in a mantra's gallery (`deity_images` of
/// `GET /mantras/{id}/images`), offered in the Change image sheet.
class MalaImageOption extends Equatable {
  const MalaImageOption({
    required this.id,
    required this.image,
    this.isDefault = false,
  });

  final String id;
  final ResponsiveImage image;

  /// The mantra's default image. Choosing it saves no pick, so the user keeps
  /// following the default if Studio changes it.
  final bool isDefault;

  @override
  List<Object?> get props => [id, image, isDefault];
}
