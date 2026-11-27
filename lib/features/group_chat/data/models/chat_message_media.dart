import 'package:equatable/equatable.dart';

class ChatMessageMedia extends Equatable {
  final String id;
  final String mediaType; // IMAGE or VIDEO
  final String quality; // STANDARD or HD
  final String? url;
  final String? thumbnailUrl;
  final String mimeType;
  final int fileSizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;

  const ChatMessageMedia({
    required this.id,
    required this.mediaType,
    required this.quality,
    this.url,
    this.thumbnailUrl,
    required this.mimeType,
    required this.fileSizeBytes,
    this.width,
    this.height,
    this.durationMs,
  });

  factory ChatMessageMedia.fromJson(Map<String, dynamic> json) {
    return ChatMessageMedia(
      id: json['id'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      mimeType: json['mime_type'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media_type': mediaType,
      'quality': quality,
      if (url != null) 'url': url,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
    };
  }

  @override
  List<Object?> get props => [
        id,
        mediaType,
        quality,
        url,
        thumbnailUrl,
        mimeType,
        fileSizeBytes,
        width,
        height,
        durationMs,
      ];
}

class ChatMessageMediaSummary extends Equatable {
  final String mediaType;
  final int count;
  final String? thumbnailUrl;

  const ChatMessageMediaSummary({
    required this.mediaType,
    required this.count,
    this.thumbnailUrl,
  });

  factory ChatMessageMediaSummary.fromJson(Map<String, dynamic> json) {
    return ChatMessageMediaSummary(
      mediaType: json['media_type'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media_type': mediaType,
      'count': count,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    };
  }

  @override
  List<Object?> get props => [mediaType, count, thumbnailUrl];
}
