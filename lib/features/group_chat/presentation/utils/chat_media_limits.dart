import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/l10n/intl_format_locale.dart';
import 'package:flutter_pecha/core/utils/tibetan_numerals.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_thread_rows.dart';
import 'package:intl/intl.dart';

/// A message holds 1-10 photos or exactly one video (`ChatMediaType` in the
/// API). Mixing the two in one message is not allowed.
const kChatMaxPhotos = 10;

/// Largest video a member can attach, before compression.
const kChatMaxVideoMb = 40;
const kChatMaxVideoBytes = kChatMaxVideoMb * 1024 * 1024;

/// Longest video a member can attach.
const kChatMaxVideoDuration = Duration(seconds: 120);

/// Why a video can't be attached, or null when it can.
sealed class ChatVideoProblem {
  const ChatVideoProblem();
}

class ChatVideoTooLarge extends ChatVideoProblem {
  const ChatVideoTooLarge(this.bytes);
  final int bytes;

  /// One decimal place, e.g. `52.0`; whole numbers drop the `.0`.
  String get megabytes {
    final mb = bytes / (1024 * 1024);
    final fixed = mb.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}

class ChatVideoTooLong extends ChatVideoProblem {
  const ChatVideoTooLong(this.duration);
  final Duration duration;
}

/// Checks a video against the chat limits. Size wins over duration, since a
/// long clip is usually also the large one and size is what the user can
/// see in the gallery tile.
ChatVideoProblem? validateChatVideo({
  required int bytes,
  required Duration duration,
}) {
  if (bytes > kChatMaxVideoBytes) return ChatVideoTooLarge(bytes);
  if (duration > kChatMaxVideoDuration) return ChatVideoTooLong(duration);
  return null;
}

/// The red line under the gallery or camera preview for [problem].
/// [fromCamera] swaps "so it can’t be added" for "Record a shorter clip.".
String chatVideoProblemMessage(
  BuildContext context,
  ChatVideoProblem problem, {
  required bool fromCamera,
}) {
  final l10n = context.l10n;
  return switch (problem) {
    ChatVideoTooLarge() =>
      fromCamera
          ? l10n.group_chat_media_camera_too_large(
            problem.megabytes,
            kChatMaxVideoMb,
          )
          : l10n.group_chat_media_video_too_large(
            problem.megabytes,
            kChatMaxVideoMb,
          ),
    ChatVideoTooLong() =>
      fromCamera
          ? l10n.group_chat_media_camera_too_long(
            formatChatDuration(problem.duration),
            formatChatDuration(kChatMaxVideoDuration),
          )
          : l10n.group_chat_media_video_too_long(
            formatChatDuration(problem.duration),
            formatChatDuration(kChatMaxVideoDuration),
          ),
  };
}

/// `m:ss`, as on the video badges (`0:42`, `4:10`).
String formatChatDuration(Duration duration) {
  final total = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// "Today, 12:03 PM", "Yesterday, 9:10 AM", "Mar 4, 9:10 AM" — the media
/// viewer's subtitle under the sender's name.
String chatMediaSentLabel(BuildContext context, DateTime at, {DateTime? now}) {
  final locale = intlFormatLocaleOf(context);
  final time = DateFormat.jm(locale).format(at);
  final day = switch (chatDateLabelKind(at, now ?? DateTime.now())) {
    ChatDateLabelKind.today => context.l10n.group_chat_today,
    ChatDateLabelKind.yesterday => context.l10n.group_chat_yesterday,
    ChatDateLabelKind.thisYear => DateFormat.MMMd(locale).format(at),
    ChatDateLabelKind.older => DateFormat.yMMMd(locale).format(at),
  };
  final label = '$day, $time';
  return context.isTibetanLocale ? toTibetanDigits(label) : label;
}
