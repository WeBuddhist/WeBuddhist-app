import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/features/group_chat/domain/repositories/group_chat_repository.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_uploader.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_picker_sheet.dart';

/// Opens the attach bottom sheet (Gallery / Camera).
void showChatMediaAttachSheet(
  BuildContext context, {
  required void Function(List<File> files, String mediaType, String caption)
      onMediaSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ChatMediaPickerSheet(onMediaSelected: onMediaSelected),
  );
}

/// Compresses and uploads files; returns API `media_type` values (`IMAGE` / `VIDEO`).
Future<ChatMediaUploadResult> uploadChatMediaFiles({
  required GroupChatRepository repository,
  required List<File> files,
  required String mediaType,
  void Function(int current, int total)? onProgress,
}) {
  final apiType = mediaType == 'VIDEO' ? 'VIDEO' : 'IMAGE';
  final uploader = ChatMediaUploader(
    repository: repository,
    onProgress: onProgress ?? (_, __) {},
  );
  return uploader.compressAndUpload(files: files, mediaType: apiType);
}

/// Starts upload and returns a handle the UI can [ChatMediaUploader.cancel].
({ChatMediaUploader uploader, Future<ChatMediaUploadResult> future})
    startChatMediaUpload({
  required GroupChatRepository repository,
  required List<File> files,
  required String mediaType,
  void Function(int current, int total)? onProgress,
}) {
  final apiType = mediaType == 'VIDEO' ? 'VIDEO' : 'IMAGE';
  final uploader = ChatMediaUploader(
    repository: repository,
    onProgress: onProgress ?? (_, __) {},
  );
  final future = uploader.compressAndUpload(files: files, mediaType: apiType);
  return (uploader: uploader, future: future);
}