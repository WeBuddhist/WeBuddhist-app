import 'package:equatable/equatable.dart';

/// The practice space a prayer request was posted in, as
/// `GET /chat/prayer-requests/me` names it (`group`). Null on the request
/// when the space has since been deleted.
class PrayerRequestGroupDTO extends Equatable {
  final String id;
  final String? slug;
  final String? name;
  final String? avatarUrl;

  const PrayerRequestGroupDTO({
    required this.id,
    this.slug,
    this.name,
    this.avatarUrl,
  });

  factory PrayerRequestGroupDTO.fromJson(Map<String, dynamic> json) {
    return PrayerRequestGroupDTO(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (slug != null) 'slug': slug,
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }

  @override
  List<Object?> get props => [id, slug, name, avatarUrl];
}

/// The event whose chat a prayer request was posted in (`event`). Only
/// present for requests made from an event.
class PrayerRequestEventDTO extends Equatable {
  final String id;
  final String? name;

  /// The event picture's `thumbnail` / `medium` / `original` sizes.
  final String? imageThumbnail;
  final String? imageMedium;
  final String? imageOriginal;

  const PrayerRequestEventDTO({
    required this.id,
    this.name,
    this.imageThumbnail,
    this.imageMedium,
    this.imageOriginal,
  });

  /// The smallest picture there is, for the source row's icon.
  String? get thumbnailUrl =>
      _firstNonEmpty([imageThumbnail, imageMedium, imageOriginal]);

  factory PrayerRequestEventDTO.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    final sizes = image is Map<String, dynamic> ? image : null;
    return PrayerRequestEventDTO(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      imageThumbnail: sizes?['thumbnail'] as String?,
      imageMedium: sizes?['medium'] as String?,
      imageOriginal: sizes?['original'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final hasImage =
        imageThumbnail != null || imageMedium != null || imageOriginal != null;
    return {
      'id': id,
      if (name != null) 'name': name,
      if (hasImage)
        'image': {
          if (imageThumbnail != null) 'thumbnail': imageThumbnail,
          if (imageMedium != null) 'medium': imageMedium,
          if (imageOriginal != null) 'original': imageOriginal,
        },
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    imageThumbnail,
    imageMedium,
    imageOriginal,
  ];
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
