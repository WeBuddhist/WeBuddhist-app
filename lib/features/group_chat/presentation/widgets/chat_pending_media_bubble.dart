import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_dto.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_badges.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_picker_sheet.dart';
import 'package:video_player/video_player.dart';

/// An outgoing media message that has not reached the server yet: what was
/// picked, how far the upload is, and whether it failed. Kept by the chat
/// screen so a failed send can be retried with the same files and caption.
class ChatPendingMedia {
  const ChatPendingMedia({
    required this.files,
    required this.mediaType,
    required this.caption,
    required this.parent,
    required this.current,
    required this.total,
    this.progress = 0,
    this.failed = false,
  });

  final List<File> files;

  /// `IMAGE` or `VIDEO`.
  final String mediaType;
  final String caption;

  /// The message being replied to, if any, kept for a retry.
  final ChatMessageDTO? parent;
  final int current;
  final int total;

  /// Overall upload progress, 0 to 1, drawn as the ring.
  final double progress;
  final bool failed;

  bool get isVideo => mediaType == 'VIDEO';

  ChatPendingMedia copyWith({
    int? current,
    int? total,
    double? progress,
    bool? failed,
  }) {
    return ChatPendingMedia(
      files: files,
      mediaType: mediaType,
      caption: caption,
      parent: parent,
      current: current ?? this.current,
      total: total ?? this.total,
      progress: progress ?? this.progress,
      failed: failed ?? this.failed,
    );
  }
}

/// The pending message drawn in the thread, as in the "Sending" and "Not
/// sent" frames: the picked media under a dim overlay with a spinner and
/// "Sending 2 of 3", Cancel where the time goes; or a retry circle and
/// "Failed".
class ChatPendingMediaBubble extends StatelessWidget {
  const ChatPendingMediaBubble({
    super.key,
    required this.pending,
    required this.onCancel,
    required this.onRetry,
    this.avatar,
  });

  final ChatPendingMedia pending;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  /// The sender's avatar beside the bubble; a direct chat leaves it out.
  final Widget? avatar;

  static const _width = 240.0;
  static const _gap = 3.0;
  static const _tileRadius = BorderRadius.all(Radius.circular(10));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.chatOutgoingBubbleDark : AppColors.chatOutgoingBubble;
    final caption = pending.caption.trim();
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    final bubble = Container(
      width: _width,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                _collage(isDark),
                Positioned.fill(child: _overlay(context)),
              ],
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                caption,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 16, color: textColor),
              ),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _meta(context, isDark),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: bubble),
          if (avatar != null) ...[const SizedBox(width: 8), avatar!],
        ],
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child:
            pending.failed
                ? Semantics(
                  button: true,
                  label: context.l10n.group_chat_retry,
                  child: GestureDetector(
                    onTap: onRetry,
                    child: const ChatVideoPlayBadge(
                      icon: AppAssets.arrowCounterClockwise,
                    ),
                  ),
                )
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChatUploadRing(progress: pending.progress),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.group_chat_media_sending(
                        (pending.current + 1).clamp(1, pending.total),
                        pending.total,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _meta(BuildContext context, bool isDark) {
    final cancel = GestureDetector(
      onTap: onCancel,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          context.l10n.cancel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
    if (!pending.failed) {
      return Align(alignment: Alignment.centerRight, child: cancel);
    }
    return Row(
      children: [
        cancel,
        const Spacer(),
        const Icon(
          AppAssets.warningCircle,
          size: 13,
          color: chatMediaErrorColor,
        ),
        const SizedBox(width: 3),
        Text(
          context.l10n.group_chat_media_failed,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: chatMediaErrorColor,
          ),
        ),
      ],
    );
  }

  /// Same shapes as the sent bubble: one, two side by side, or a hero over
  /// two squares; a fourth onward is folded into "+N".
  Widget _collage(bool isDark) {
    const inner = _width - 8;
    final files = pending.files;
    if (pending.isVideo || files.length == 1) {
      return SizedBox(
        width: inner,
        height: 160,
        child: _tile(files.first, isDark, isVideo: pending.isVideo),
      );
    }
    if (files.length == 2) {
      return SizedBox(
        height: (inner - _gap) / 2,
        child: Row(
          children: [
            Expanded(child: _tile(files[0], isDark)),
            const SizedBox(width: _gap),
            Expanded(child: _tile(files[1], isDark)),
          ],
        ),
      );
    }
    final hidden = files.length - 3;
    const square = (inner - _gap) / 2;
    return Column(
      children: [
        SizedBox(height: 160, width: inner, child: _tile(files[0], isDark)),
        const SizedBox(height: _gap),
        SizedBox(
          height: square,
          child: Row(
            children: [
              Expanded(child: _tile(files[1], isDark)),
              const SizedBox(width: _gap),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _tile(files[2], isDark),
                    if (hidden > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: _tileRadius,
                        ),
                        child: Center(
                          child: Text(
                            '+$hidden',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(File file, bool isDark, {bool isVideo = false}) {
    const skeleton = ChatMediaSkeleton();
    final Widget tile =
        isVideo
            ? _LocalVideoFrame(
              key: ValueKey(file.path),
              file: file,
              placeholder: skeleton,
            )
            : Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 480,
              frameBuilder:
                  (_, child, frame, sync) =>
                      frame == null && !sync ? skeleton : child,
              errorBuilder:
                  (_, _, _) => ColoredBox(
                    color: isDark ? AppColors.grey800 : AppColors.grey300,
                    child: Icon(
                      AppAssets.image,
                      color: isDark ? AppColors.grey500 : AppColors.grey600,
                    ),
                  ),
            );
    return ClipRRect(borderRadius: _tileRadius, child: tile);
  }
}

/// WhatsApp-style ring: a faint full circle that fills clockwise as the
/// upload goes, never spinning. 40px with a 3px stroke, inside a 44px box.
class ChatUploadRing extends StatelessWidget {
  const ChatUploadRing({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder:
                (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.35),
                ),
          ),
        ),
      ),
    );
  }
}

/// The first frame of a local video, paused, as the pending poster.
class _LocalVideoFrame extends StatefulWidget {
  const _LocalVideoFrame({
    super.key,
    required this.file,
    required this.placeholder,
  });

  final File file;
  final Widget placeholder;

  @override
  State<_LocalVideoFrame> createState() => _LocalVideoFrameState();
}

class _LocalVideoFrameState extends State<_LocalVideoFrame> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.file(widget.file);
    _controller = controller;
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return widget.placeholder;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}
