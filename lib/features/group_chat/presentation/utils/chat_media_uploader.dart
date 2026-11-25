import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pecha/features/group_chat/domain/repositories/group_chat_repository.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_cleanup.dart';

class ChatMediaUploadResult {
  final List<String> mediaIds;
  final bool isCancelled;
  final bool failed;

  ChatMediaUploadResult({
    required this.mediaIds,
    this.isCancelled = false,
    this.failed = false,
  });
}

class ChatMediaUploader {
  ChatMediaUploader({
    required GroupChatRepository repository,
    required void Function(int current, int total) onProgress,
  })  : _repository = repository,
        _onProgress = onProgress;

  final GroupChatRepository _repository;
  final void Function(int current, int total) _onProgress;

  bool _isCancelled = false;
  final List<String> _uploadedMediaIds = [];

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

        final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.DefaultQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

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
            _onProgress(1, 1);
            return ChatMediaUploadResult(mediaIds: List.unmodifiable(_uploadedMediaIds));
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
            _onProgress(i + 1, totalCount);
            return null;
          },
        );

        if (stepResult != null) {
          await _cleanupPendingUploads();
          return stepResult;
        }
      }

      return ChatMediaUploadResult(mediaIds: List.unmodifiable(_uploadedMediaIds));
    } catch (_) {
      await _cleanupPendingUploads();
      return ChatMediaUploadResult(mediaIds: [], failed: true);
    }
  }
}