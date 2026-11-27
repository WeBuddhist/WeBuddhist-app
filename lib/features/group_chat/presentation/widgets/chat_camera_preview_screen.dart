import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_limits.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_badges.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_picker_sheet.dart';
import 'package:video_player/video_player.dart';

/// Shows what the phone camera just captured, with a caption field and send,
/// as in the "Camera" frames. A video over the limits shows the red line and
/// cannot be sent.
Future<void> showChatCameraPreview(
  NavigatorState navigator, {
  required File file,
  required bool isVideo,
  required void Function(File file, String caption) onSend,
}) {
  return navigator.push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder:
          (_) => ChatCameraPreviewScreen(
            file: file,
            isVideo: isVideo,
            onSend: onSend,
          ),
    ),
  );
}

class ChatCameraPreviewScreen extends StatefulWidget {
  const ChatCameraPreviewScreen({
    super.key,
    required this.file,
    required this.isVideo,
    required this.onSend,
    this.videoControllerFactory,
  });

  final File file;
  final bool isVideo;
  final void Function(File file, String caption) onSend;

  /// Tests swap in a fake controller; the app plays the file.
  final VideoPlayerController Function(File file)? videoControllerFactory;

  @override
  State<ChatCameraPreviewScreen> createState() =>
      _ChatCameraPreviewScreenState();
}

class _ChatCameraPreviewScreenState extends State<ChatCameraPreviewScreen> {
  final _captionController = TextEditingController();
  VideoPlayerController? _video;
  ChatVideoProblem? _problem;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      unawaited(_prepareVideo());
    } else {
      _checked = true;
    }
  }

  Future<void> _prepareVideo() async {
    final controller =
        widget.videoControllerFactory?.call(widget.file) ??
        VideoPlayerController.file(widget.file);
    _video = controller;
    controller.addListener(_onVideoTick);
    int bytes = 0;
    try {
      bytes = await widget.file.length();
    } catch (_) {}
    try {
      await controller.initialize();
    } catch (_) {
      // The poster stays black; the size check still applies.
    }
    if (!mounted) return;
    setState(() {
      _problem = validateChatVideo(
        bytes: bytes,
        duration: controller.value.duration,
      );
      _checked = true;
    });
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _send() {
    final caption = _captionController.text.trim();
    Navigator.of(context).pop();
    widget.onSend(widget.file, caption);
  }

  void _togglePlay() {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    video.value.isPlaying ? video.pause() : video.play();
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final canSend = _checked && problem == null;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(AppAssets.x, color: Colors.white),
                tooltip: context.l10n.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: widget.isVideo ? _videoPreview() : _photoPreview(),
            ),
            if (problem != null)
              ChatMediaErrorLine(
                text: chatVideoProblemMessage(
                  context,
                  problem,
                  fromCamera: true,
                ),
                onDark: true,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ChatCaptionField(
                      controller: _captionController,
                      hintText: context.l10n.group_chat_media_camera_caption_hint,
                      fill: const Color(0xFF222222),
                      textColor: Colors.white,
                      hintColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChatSendButton(
                    enabled: canSend,
                    onPressed: _send,
                    color: const Color(0xFFE8E8E8),
                    iconColor: Colors.black,
                    disabledColor: const Color(0xFF3A3A3A),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPreview() {
    return Center(
      child: Image.file(
        widget.file,
        fit: BoxFit.contain,
        errorBuilder:
            (_, _, _) => const Icon(AppAssets.image, color: Colors.white54),
      ),
    );
  }

  Widget _videoPreview() {
    final video = _video;
    final ready = video != null && video.value.isInitialized;
    final duration = ready ? video.value.duration : Duration.zero;

    return GestureDetector(
      onTap: _togglePlay,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ready)
            AspectRatio(
              aspectRatio:
                  video.value.aspectRatio <= 0 ? 16 / 9 : video.value.aspectRatio,
              child: VideoPlayer(video),
            )
          else
            const SizedBox.expand(),
          if (!ready || !video.value.isPlaying) const ChatVideoPlayBadge(),
          if (ready)
            Positioned(
              left: 12,
              bottom: 12,
              child: ChatDurationBadge(duration: duration),
            ),
        ],
      ),
    );
  }
}
