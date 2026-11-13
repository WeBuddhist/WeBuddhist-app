// Models for user recitation-collection endpoints under
// `/users/me/recitation-collections`.
//
// Separate from group-scoped collections (`GroupRecitationCollectionModel`).

import 'package:flutter_pecha/core/utils/audio_url.dart';

/// Request body for `POST /users/me/recitation-collections`.
class CreateMyRecitationCollectionRequest {
  final String name;

  /// Storage key returned by [MyRecitationCollectionImageUploadResponse.key].
  ///
  /// The API marks `img_url` required (non-nullable), so a collection created
  /// without a cover sends an empty string; readers treat empty as "no image".
  final String imgUrl;

  const CreateMyRecitationCollectionRequest({
    required this.name,
    required this.imgUrl,
  });

  Map<String, dynamic> toJson() => {'name': name, 'img_url': imgUrl};
}

/// Request body for `PUT /users/me/recitation-collections/{id}`.
///
/// [imgUrl] is the storage key from a prior upload. Omit when the cover is
/// unchanged so the API keeps the existing image.
class UpdateMyRecitationCollectionRequest {
  final String name;
  final String? imgUrl;

  const UpdateMyRecitationCollectionRequest({required this.name, this.imgUrl});

  Map<String, dynamic> toJson() => {
    'name': name,
    if (imgUrl != null && imgUrl!.isNotEmpty) 'img_url': imgUrl,
  };
}

/// Request body for
/// `PATCH /users/me/recitation-collections/{collectionId}/items/{itemId}`.
class UpdateMyRecitationCollectionItemDisplayOrderRequest {
  final double displayOrder;

  const UpdateMyRecitationCollectionItemDisplayOrderRequest({
    required this.displayOrder,
  });

  Map<String, dynamic> toJson() => {'display_order': displayOrder};
}

/// Nested image URLs from `POST .../upload-image`.
class MyRecitationCollectionUploadedImage {
  final String? thumbnail;
  final String? medium;
  final String? original;

  const MyRecitationCollectionUploadedImage({
    this.thumbnail,
    this.medium,
    this.original,
  });

  factory MyRecitationCollectionUploadedImage.fromJson(
    Map<String, dynamic> json,
  ) {
    return MyRecitationCollectionUploadedImage(
      thumbnail: json['thumbnail'] as String?,
      medium: json['medium'] as String?,
      original: json['original'] as String?,
    );
  }

  /// Best URL for local preview after upload.
  String? get displayUrl => medium ?? original ?? thumbnail;
}

/// Response from `POST /users/me/recitation-collections/upload-image` (201).
class MyRecitationCollectionImageUploadResponse {
  final MyRecitationCollectionUploadedImage? image;

  /// Pass this value as `img_url` when creating/updating a collection.
  final String key;
  final String? path;
  final String? message;

  const MyRecitationCollectionImageUploadResponse({
    required this.key,
    this.image,
    this.path,
    this.message,
  });

  factory MyRecitationCollectionImageUploadResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final imageJson = json['image'];
    return MyRecitationCollectionImageUploadResponse(
      key: json['key'] as String? ?? '',
      image:
          imageJson is Map<String, dynamic>
              ? MyRecitationCollectionUploadedImage.fromJson(imageJson)
              : null,
      path: json['path'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// `scope` of `GET /users/me/recitation-collections`.
enum RecitationCollectionScope {
  /// The user's own collections (server default).
  own('own'),

  /// Own collections plus the ones the user imported.
  withImports('with_imports'),

  /// PUBLIC collections the user can import.
  public('public');

  const RecitationCollectionScope(this.apiValue);
  final String apiValue;
}

/// Response from `POST /users/me/recitation-collections` (201).
class MyRecitationCollectionModel {
  final String id;
  final String name;
  final String? imgUrl;
  final int itemCount;

  /// Chants that have at least one recording. Not sent yet; requested from
  /// the backend (Q2), so it reads 0 until then.
  final int audioItemCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Who made the collection: the source's owner for an import
  /// (`reference.owner`), else `owner` (sent for `scope=public`). Null for
  /// the user's own collections.
  final String? ownerName;

  /// True when the user imported this collection by reference.
  final bool isImported;

  const MyRecitationCollectionModel({
    required this.id,
    required this.name,
    this.imgUrl,
    this.itemCount = 0,
    this.audioItemCount = 0,
    this.createdAt,
    this.updatedAt,
    this.ownerName,
    this.isImported = false,
  });

  bool get hasAudio => audioItemCount > 0;

  factory MyRecitationCollectionModel.fromJson(Map<String, dynamic> json) {
    final reference = json['reference'];
    final referenceOwner =
        reference is Map<String, dynamic> ? reference['owner'] : null;
    return MyRecitationCollectionModel(
      id: json['id'] as String? ?? json['collection_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imgUrl: json['img_url'] as String?,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      audioItemCount: (json['audio_item_count'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      ownerName: _ownerName(referenceOwner) ?? _ownerName(json['owner']),
      isImported: reference is Map<String, dynamic>,
    );
  }

  static String? _ownerName(Object? owner) {
    if (owner is! Map<String, dynamic>) return null;
    final name = (owner['name'] as String?)?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Response from `GET /users/me/recitation-collections` (200).
class MyRecitationCollectionsPageResponse {
  final List<MyRecitationCollectionModel> collections;
  final int skip;
  final int limit;
  final int total;

  const MyRecitationCollectionsPageResponse({
    required this.collections,
    required this.skip,
    required this.limit,
    required this.total,
  });

  factory MyRecitationCollectionsPageResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rows = json['collections'] as List<dynamic>? ?? const [];
    return MyRecitationCollectionsPageResponse(
      collections: rows
          .whereType<Map<String, dynamic>>()
          .map(MyRecitationCollectionModel.fromJson)
          .toList(growable: false),
      skip: (json['skip'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? rows.length,
      total: (json['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  bool get hasMore => skip + collections.length < total;
}

/// Response from `GET /users/me/recitation-collections/{id}` (200).
class MyRecitationCollectionDetailModel {
  final String id;
  final String name;
  final String? imgUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MyRecitationCollectionItemModel> items;

  /// The source's owner for an imported collection (`reference.owner`),
  /// else `owner`; null for the user's own.
  final String? ownerName;

  /// True when the user imported this collection by reference. Such a
  /// collection is someone else's: it cannot be renamed, edited or deleted
  /// from here.
  final bool isImported;

  const MyRecitationCollectionDetailModel({
    required this.id,
    required this.name,
    this.imgUrl,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.ownerName,
    this.isImported = false,
  });

  factory MyRecitationCollectionDetailModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items =
        rawItems
            .whereType<Map<String, dynamic>>()
            .map(MyRecitationCollectionItemModel.fromJson)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final reference = json['reference'];
    final referenceOwner =
        reference is Map<String, dynamic> ? reference['owner'] : null;

    return MyRecitationCollectionDetailModel(
      id: json['id'] as String? ?? json['collection_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imgUrl: json['img_url'] as String?,
      createdAt: MyRecitationCollectionModel._parseDate(json['created_at']),
      updatedAt: MyRecitationCollectionModel._parseDate(json['updated_at']),
      items: items,
      ownerName:
          MyRecitationCollectionModel._ownerName(referenceOwner) ??
          MyRecitationCollectionModel._ownerName(json['owner']),
      isImported: reference is Map<String, dynamic>,
    );
  }
}

/// Request body for `POST /users/me/recitation-collections/{id}/items`.
class AddMyRecitationCollectionItemsRequest {
  final List<String> textIds;

  const AddMyRecitationCollectionItemsRequest({required this.textIds});

  Map<String, dynamic> toJson() => {'text_ids': textIds};
}

/// Request body for `POST /users/me/recitation-collections/{id}/complete`.
class CompleteMyRecitationCollectionChantRequest {
  final String chantId;

  const CompleteMyRecitationCollectionChantRequest({required this.chantId});

  Map<String, dynamic> toJson() => {'chant_id': chantId};
}

/// Response from
/// `GET /users/me/recitation-collections/{id}/complete/today` (200).
class MyRecitationCollectionTodayCompletionsResponse {
  final Set<String> completedChantIds;
  final DateTime? date;

  const MyRecitationCollectionTodayCompletionsResponse({
    this.completedChantIds = const {},
    this.date,
  });

  factory MyRecitationCollectionTodayCompletionsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return MyRecitationCollectionTodayCompletionsResponse(
      completedChantIds:
          (json['completed_chant_ids'] as List<dynamic>?)
              ?.whereType<String>()
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet() ??
          const {},
      date: MyRecitationCollectionModel._parseDate(json['date']),
    );
  }
}

/// Response from
/// `GET /users/me/recitation-collections/{id}/complete/days-count` (200).
class MyRecitationCollectionCompletionDaysCountResponse {
  final String collectionId;
  final int dayCount;

  const MyRecitationCollectionCompletionDaysCountResponse({
    required this.collectionId,
    required this.dayCount,
  });

  factory MyRecitationCollectionCompletionDaysCountResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return MyRecitationCollectionCompletionDaysCountResponse(
      collectionId: json['collection_id'] as String? ?? '',
      dayCount: (json['day_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One recording attached to a personal collection chant (`ItemAudioDTO`).
class MyRecitationCollectionItemAudioModel {
  final String id;
  final String title;
  final String url;
  final int? durationMs;
  final int displayOrder;

  /// Not sent yet; requested from the backend (Q3).
  final String? reciterName;

  /// Not sent yet; requested from the backend (Q3).
  final String? imageUrl;

  const MyRecitationCollectionItemAudioModel({
    required this.id,
    required this.title,
    required this.url,
    this.durationMs,
    this.displayOrder = 0,
    this.reciterName,
    this.imageUrl,
  });

  factory MyRecitationCollectionItemAudioModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return MyRecitationCollectionItemAudioModel(
      id: json['id'] as String? ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      url: json['url'] as String? ?? '',
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      reciterName: _blankToNull(json['reciter_name']),
      imageUrl: _blankToNull(json['image_url']),
    );
  }

  static String? _blankToNull(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// A chant row returned after adding items to a collection.
class MyRecitationCollectionItemModel {
  final String id;
  final String textId;
  final String? title;
  final String? language;
  final String? type;
  final double displayOrder;

  /// Playable recordings in their display order.
  final List<MyRecitationCollectionItemAudioModel> audio;

  const MyRecitationCollectionItemModel({
    required this.id,
    required this.textId,
    this.title,
    this.language,
    this.type,
    this.displayOrder = 0,
    this.audio = const [],
  });

  bool get hasAudio => audio.isNotEmpty;

  factory MyRecitationCollectionItemModel.fromJson(Map<String, dynamic> json) {
    return MyRecitationCollectionItemModel(
      id: json['id'] as String? ?? json['chant_id'] as String? ?? '',
      textId: json['text_id'] as String? ?? '',
      title: json['title'] as String?,
      language: json['language'] as String?,
      type: json['type'] as String?,
      displayOrder: (json['display_order'] as num?)?.toDouble() ?? 0,
      audio: _parseAudio(json['audio']),
    );
  }

  /// Drops recordings without a playable URL, then sorts by display order.
  static List<MyRecitationCollectionItemAudioModel> _parseAudio(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MyRecitationCollectionItemAudioModel.fromJson)
        .where((audio) => hasPlayableAudio(audio.url))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }
}

/// Response from `POST /users/me/recitation-collections/{id}/items` (201).
class AddMyRecitationCollectionItemsResponse {
  final String collectionId;
  final int addedCount;
  final List<MyRecitationCollectionItemModel> items;

  const AddMyRecitationCollectionItemsResponse({
    required this.collectionId,
    required this.addedCount,
    this.items = const [],
  });

  factory AddMyRecitationCollectionItemsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return AddMyRecitationCollectionItemsResponse(
      collectionId: json['collection_id'] as String? ?? '',
      addedCount: (json['added_count'] as num?)?.toInt() ?? 0,
      items:
          rawItems
              .whereType<Map<String, dynamic>>()
              .map(MyRecitationCollectionItemModel.fromJson)
              .toList(),
    );
  }
}
