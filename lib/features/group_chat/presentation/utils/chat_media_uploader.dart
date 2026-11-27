import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pecha/features/group_chat/domain/repositories/group_chat_repository.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_local_media_cache.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_cleanup.dart';

class ChatMediaUploadResult {
  final List<String> mediaIds;
  final bool isCancelled;
  final bool failed;

  /// The compressed files sent for each id in [mediaIds], so the sent
  /// message can paint from them instead of downloading its own media.
  final Map<String, ChatLocalMediaFiles> localFiles;

  ChatMediaUploadResult({
    required this.mediaIds,
    this.isCancelled = false,
    this.failed = false,
    this.localFiles = const {},
  });
}

class ChatMediaUploader {
  ChatMediaUploader({
    required GroupChatRepository repository,
    required void Function(int current, int total) onProgress,
    void Function(double fraction)? onFraction,
  })  : _repository = repository,
        _onProgress = onProgress,
        _onFraction = onFraction;

  final GroupChatRepository _repository;
  final void Function(int current, int total) _onProgress;

  /// Overall progress, 0 to 1, for the ring on the pending bubble. Never goes
  /// backwards, so the ring only ever fills.
  final void Function(double fraction)? _onFraction;
  double _fraction = 0;

  void _report(double fraction) {
    final next = fraction.clamp(0.0, 1.0);
    if (next <= _fraction) return;
    _fraction = next;
    _onFraction?.call(next);
  }

  /// Share of a video's progress taken by compressing it on the device.
  static const _videoCompressShare = 0.4;

  /// Share of each photo's slice taken by compressing it.
  static const _photoCompressShare = 0.15;

  bool _isCancelled = false;
  final List<String> _uploadedMediaIds = [];
  final Map<String, ChatLocalMediaFiles> _localFiles = {};

  ChatMediaUploadResult _success() => ChatMediaUploadResult(
    mediaIds: List.unmodifiable(_uploadedMediaIds),
    localFiles: Map.unmodifiable(_localFiles),
  );

  void cancel() {
    _isCancelled = true;
    unawaited(VideoCompress.cancelCompression());
    unawaited(_cleanupPendingUploads());
  }

  Future<void> _cleanupPendingUploads() async {
    final ids = List<String>.from(_uploadedMediaIds);
    _uploadedMediaIds.clear();
    await deletePendingChatMedia(_repository, ids);
  }

  Future<ChatMediaUploadResult> compressAndUpload({
    required List<File> files,
    required String mediaType,
  }) async {
    final totalCount = files.length;
    _onProgress(0, totalCount);

    try {
      if (mediaType == 'VIDEO') {
        if (_isCancelled) {
          return ChatMediaUploadResult(mediaIds: [], isCancelled: true);
        }

        final videoFile = files.first;

        final compressing = VideoCompress.compressProgress$.subscribe(
          (percent) => _report(percent / 100 * _videoCompressShare),
        );
        final MediaInfo? mediaInfo;
        try {
          mediaInfo = await VideoCompress.compressVideo(
            videoFile.path,
            quality: VideoQuality.DefaultQuality,
            deleteOrigin: false,
            includeAudio: true,
          );
        } finally {
          compressing.unsubscribe();
        }
        _report(_videoCompressShare);

        if (_isCancelled || mediaInfo == null || mediaInfo.file == null) {
          await _cleanupPendingUploads();
          return ChatMediaUploadResult(mediaIds: [], isCancelled: _isCancelled);
        }

        final compressedVideoFile = mediaInfo.file!;

        final File thumbnailFile = await VideoCompress.getFileThumbnail(
          videoFile.path,
          quality: 85,
        );

        if (_isCancelled) {
          await _cleanupPendingUploads();
          return ChatMediaUploadResult(mediaIds: [], isCancelled: true);
        }

        int? width;
        int? height;
        try {
          final image =
              await decodeImageFromList(await thumbnailFile.readAsBytes());
          width = image.width;
          height = image.height;
          image.dispose();
        } catch (_) {}

        final result = await _repository.uploadChatMedia(
          fileBytes: await compressedVideoFile.readAsBytes(),
          filename: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          mediaType: 'VIDEO',
          quality: 'STANDARD',
          posterBytes: await thumbnailFile.readAsBytes(),
          posterFilename:
              'poster_${DateTime.now().millisecondsSinceEpoch}.jpg',
          width: width,
          height: height,
          onSendProgress: (sent, total) {
            if (total <= 0) return;
            _report(
              _videoCompressShare + (1 - _videoCompressShare) * sent / total,
            );
          },
        );

        if (_isCancelled) {
          await _cleanupPendingUploads();
          return ChatMediaUploadResult(mediaIds: [], isCancelled: true);
        }

        return result.fold(
          (_) {
            return ChatMediaUploadResult(mediaIds: [], failed: true);
          },
          (media) {
            _uploadedMediaIds.add(media.id);
            _localFiles[media.id] = ChatLocalMediaFiles(
              image: thumbnailFile,
              video: compressedVideoFile,
            );
            _report(1);
            _onProgress(1, 1);
            return _success();
          },
        );
      }

      final tmpDir = await getTemporaryDirectory();

      for (var i = 0; i < totalCount; i++) {
        if (_isCancelled) {
          await _cleanupPendingUploads();
          return ChatMediaUploadResult(mediaIds: [], isCancelled: true);
        }

        final photoFile = files[i];
        final destPath =
            '${tmpDir.path}/chat_photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final XFile? compressedXFile =
            await FlutterImageCompress.compressAndGetFile(
          photoFile.path,
          destPath,
          quality: 85,
          autoCorrectionAngle: true,
        );

        if (_isCancelled || compressedXFile == null) {
          await _cleanupPendingUploads();
          return ChatMediaUploadResult(
            mediaIds: [],
            isCancelled: _isCancelled,
            failed: !_isCancelled && compressedXFile == null,
          );
        }

        final compressedFile = File(compressedXFile.path);
        _report((i + _photoCompressShare) / totalCount);

        int? width;
        int? height;
        try {
          final image =
              await decodeImageFromList(await compressedFile.readAsBytes());
          width = image.width;
          height = image.height;
          image.dispose();
        } catch (_) {}

        final result = await _repository.uploadChatMedia(
          fileBytes: await compressedFile.readAsBytes(),
          filename: 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          mediaType: 'IMAGE',
          quality: 'STANDARD',
          width: width,
          height: height,
          onSendProgress: (sent, total) {
            if (total <= 0) return;
            _report(
              (i +
                      _photoCompressShare +
                      (1 - _photoCompressShare) * sent / total) /
                  totalCount,
            );
          },
        );

        if (_isCancelled) {
          await _cleanupPendingUploads();
          return ChatMediaUploadResult(mediaIds: [], isCancelled: true);
        }

        final stepResult = result.fold(
          (_) => ChatMediaUploadResult(mediaIds: [], failed: true),
          (media) {
            if (_isCancelled) return null;
            _uploadedMediaIds.add(media.id);
            _localFiles[media.id] = ChatLocalMediaFiles(image: compressedFile);
            _report((i + 1) / totalCount);
            _onProgress(i + 1, totalCount);
            return null;
          },
        );

        if (stepResult != null) {
          await _cleanupPendingUploads();
          return stepResult;
        }
      }

      return _success();
    } catch (_) {
      await _cleanupPendingUploads();
      return ChatMediaUploadResult(mediaIds: [], failed: true);
    }
  }
}