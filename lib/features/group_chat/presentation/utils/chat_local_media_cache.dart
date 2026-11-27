import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_pecha/core/cache/app_image_cache_manager.dart';
import 'package:flutter_pecha/core/cache/chat_video_cache_manager.dart';
import 'package:flutter_pecha/core/utils/network_image_utils.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';

/// What the device itself sent for one uploaded media item: the compressed
/// photo, or a video's poster frame and compressed clip.
@immutable
class ChatLocalMediaFiles {
  const ChatLocalMediaFiles({required this.image, this.video});

  /// The photo, or the video's poster.
  final File image;
  final File? video;
}

/// Decode width shared by the pending tiles and the local placeholder of a
/// sent tile, so the second paints from the [ImageCache] entry of the first.
const chatLocalTileDecodeWidth = 480;

ImageProvider chatLocalTileProvider(File file) =>
    ResizeImage(FileImage(file), width: chatLocalTileDecodeWidth);

/// Local files for media this device just sent, by media id. A sent bubble
/// paints from these while the server copy loads, so a send never flashes
/// back to a placeholder. Lives for the app session.
class ChatLocalMediaCache {
  ChatLocalMediaCache._();

  static final ChatLocalMediaCache instance = ChatLocalMediaCache._();

  static const _maxEntries = 200;

  final _files = <String, ChatLocalMediaFiles>{};

  ChatLocalMediaFiles? operator [](String mediaId) => _files[mediaId];

  void register(String mediaId, ChatLocalMediaFiles files) {
    if (mediaId.isEmpty) return;
    _files.remove(mediaId);
    _files[mediaId] = files;
    while (_files.length > _maxEntries) {
      _files.remove(_files.keys.first);
    }
  }

  @visibleForTesting
  void clear() => _files.clear();

  /// Registers files from an upload, before the message carrying them is
  /// sent, so its bubble paints from them on its very first frame.
  void registerAll(Map<String, ChatLocalMediaFiles> localById) {
    localById.forEach(register);
  }

  /// Copies the registered files of a sent message into the disk caches
  /// under its server URLs, so a reopened chat or a restarted app shows them
  /// without downloading. Fire and forget; never throws.
  void seedDiskCaches(List<ChatMessageMedia> media) {
    for (final item in media) {
      final local = _files[item.id];
      if (local == null) continue;
      unawaited(_seedDiskCaches(item, local));
    }
  }

  Future<void> _seedDiskCaches(
    ChatMessageMedia item,
    ChatLocalMediaFiles local,
  ) async {
    try {
      final imageBytes = await local.image.readAsBytes();
      final isVideo = item.mediaType.toUpperCase() == 'VIDEO';
      final imageUrls = <String?>[item.thumbnailUrl, if (!isVideo) item.url];
      for (final url in imageUrls) {
        await _put(appImageCacheManager, url, imageBytes, 'jpg');
      }
      final video = local.video;
      if (isVideo && video != null) {
        await _put(
          chatVideoCacheManager,
          item.url,
          await video.readAsBytes(),
          'mp4',
        );
      }
    } catch (_) {
      // Seeding is an optimisation; the network copy still works.
    }
  }

  Future<void> _put(
    CacheManager manager,
    String? url,
    Uint8List bytes,
    String extension,
  ) async {
    if (url == null || url.isEmpty) return;
    final key = stableNetworkImageCacheKey(url);
    if (await manager.getFileFromCache(key) != null) return;
    await manager.putFile(url, bytes, key: key, fileExtension: extension);
  }
}

/// Width over height of a local photo, as the tile will decode it (EXIF
/// rotation applied). Also warms the [ImageCache] for that tile. Null when
/// the file can't be decoded.
Future<double?> resolveLocalImageAspect(File file) {
  final completer = Completer<double?>();
  final stream = chatLocalTileProvider(file).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      final w = info.image.width;
      final h = info.image.height;
      if (!completer.isCompleted) {
        completer.complete(w > 0 && h > 0 ? w / h : null);
      }
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete(null);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future.timeout(
    const Duration(seconds: 2),
    onTimeout: () => null,
  );
}
