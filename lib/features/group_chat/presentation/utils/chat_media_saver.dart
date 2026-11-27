import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

enum ChatMediaSaveOutcome { saved, denied, failed }

/// Downloads a chat photo or video and adds it to the device's photos.
///
/// Media URLs are presigned, so a plain client is used — the API client's
/// auth header has no business on a storage request.
Future<ChatMediaSaveOutcome> saveChatMediaToGallery({
  required String url,
  required bool isVideo,
  Dio? dio,
}) async {
  File? temp;
  try {
    if (!await Gal.hasPermission() && !await Gal.requestPermission()) {
      return ChatMediaSaveOutcome.denied;
    }
    final dir = await getTemporaryDirectory();
    final ext = _extensionOf(url) ?? (isVideo ? 'mp4' : 'jpg');
    temp = File(
      '${dir.path}/chat_media_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    await (dio ?? Dio()).download(url, temp.path);
    if (isVideo) {
      await Gal.putVideo(temp.path);
    } else {
      await Gal.putImage(temp.path);
    }
    return ChatMediaSaveOutcome.saved;
  } on GalException catch (e) {
    return e.type == GalExceptionType.permissionDenied
        ? ChatMediaSaveOutcome.denied
        : ChatMediaSaveOutcome.failed;
  } catch (_) {
    return ChatMediaSaveOutcome.failed;
  } finally {
    if (temp != null && await temp.exists()) {
      try {
        await temp.delete();
      } catch (_) {}
    }
  }
}

String? _extensionOf(String url) {
  final path = Uri.tryParse(url)?.path ?? '';
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return null;
  final ext = path.substring(dot + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? ext : null;
}
