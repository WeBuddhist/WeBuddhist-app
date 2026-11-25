import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';

bool chatMediaIsVideo(String mediaType) => mediaType == 'VIDEO';

bool chatMediaIsImage(String mediaType) =>
    mediaType == 'IMAGE' || mediaType == 'PHOTO';

/// Preview line for room list and quotes when the message has no text body.
String chatMediaListPreviewLabel(
  AppLocalizations l10n,
  List<ChatMessageMedia> media,
) {
  if (media.isEmpty) return '';

  final videos =
      media.where((m) => chatMediaIsVideo(m.mediaType)).length;
  final images =
      media.where((m) => chatMediaIsImage(m.mediaType)).length;

  if (videos > 0 && images == 0) {
    return videos == 1
        ? l10n.group_chat_preview_video
        : l10n.group_chat_preview_videos(videos);
  }
  if (images > 0 && videos == 0) {
    return images == 1
        ? l10n.group_chat_preview_photo
        : l10n.group_chat_preview_photos(images);
  }
  return l10n.group_chat_preview_media;
}

/// Preview from a parent reply stub's `media_summary`.
String chatMediaSummaryPreviewLabel(
  AppLocalizations l10n,
  ChatMessageMediaSummary summary,
) {
  if (chatMediaIsVideo(summary.mediaType)) {
    return summary.count <= 1
        ? l10n.group_chat_preview_video
        : l10n.group_chat_preview_videos(summary.count);
  }
  return summary.count <= 1
      ? l10n.group_chat_preview_photo
      : l10n.group_chat_preview_photos(summary.count);
}