import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_limits.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_saver.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_message_media_preview.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_badges.dart';
import 'package:video_player/video_player.dart';

typedef ChatMediaSaver =
    Future<ChatMediaSaveOutcome> Function({
      required String url,
      required bool isVideo,
    });

/// Full-screen photos and video from one chat message, per the "Image viewer"
/// and "Video player" frames: close, sender and time, download. Reporting is
/// on long-press in the thread, not here.
class ChatMediaViewer extends StatefulWidget {
  const ChatMediaViewer({
    super.key,
    required this.media,
    required this.senderName,
    required this.sentAt,
    this.caption = '',
    this.initialIndex = 0,
    this.saver,
    this.videoControllerFactory,
  });

  final List<ChatMessageMedia> media;
  final String senderName;
  final DateTime sentAt;

  /// The message body, shown under a photo.
  final String caption;
  final int initialIndex;

  /// Tests swap these; the app downloads to Photos and streams the video.
  final ChatMediaSaver? saver;
  final VideoPlayerController Function(Uri url)? videoControllerFactory;

  static Future<void> show(
    BuildContext context, {
    required List<ChatMessageMedia> media,
    required String senderName,
    required DateTime sentAt,
    String caption = '',
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'chat-media-viewer'),
        pageBuilder:
            (_, _, _) => ChatMediaViewer(
              media: media,
              senderName: senderName,
              sentAt: sentAt,
              caption: caption,
              initialIndex: initialIndex,
            ),
        transitionsBuilder:
            (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<ChatMediaViewer> createState() => _ChatMediaViewerState();
}

class _ChatMediaViewerState extends State<ChatMediaViewer> {
  late final PageController _pages;
  late int _index;
  bool _zoomed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.media.length - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ChatMessageMedia get _current => widget.media[_index];

  Future<void> _download() async {
    final url = _current.url ?? _current.thumbnailUrl;
    if (url == null || url.isEmpty || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _saving = true);
    final save = widget.saver ?? saveChatMediaToGallery;
    final outcome = await save(
      url: url,
      isVideo: chatMediaIsVideo(_current.mediaType),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          ChatMediaSaveOutcome.saved => l10n.group_chat_media_saved,
          ChatMediaSaveOutcome.denied => l10n.group_chat_media_save_denied,
          ChatMediaSaveOutcome.failed => l10n.group_chat_media_save_failed,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.media.length;
    final sent = chatMediaSentLabel(context, widget.sentAt);
    final subtitle =
        total > 1
            ? '$sent · ${context.l10n.group_chat_media_position(_index + 1, total)}'
            : sent;
    final caption = widget.caption.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: widget.senderName,
              subtitle: subtitle,
              saving: _saving,
              onClose: () => Navigator.of(context).pop(),
              onDownload: _download,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                physics:
                    _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                itemCount: total,
                onPageChanged:
                    (index) => setState(() {
                      _index = index;
                      _zoomed = false;
                    }),
                itemBuilder: (context, index) {
                  final item = widget.media[index];
                  if (chatMediaIsVideo(item.mediaType)) {
                    return _VideoPage(
                      key: ValueKey('video-${item.id}'),
                      media: item,
                      isActive: index == _index,
                      controllerFactory: widget.videoControllerFactory,
                    );
                  }
                  return _PhotoPage(
                    key: ValueKey('photo-${item.id}'),
                    media: item,
                    caption: caption,
                    onZoomChanged: (zoomed) {
                      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.saving,
    required this.onClose,
    required this.onDownload,
  });

  final String title;
  final String subtitle;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(AppAssets.x, color: Colors.white, size: 24),
            tooltip: context.l10n.close,
            onPressed: onClose,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.grey500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.group_chat_media_download,
            onPressed: saving ? null : onDownload,
            icon:
                saving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(
                      AppAssets.download,
                      color: Colors.white,
                      size: 24,
                    ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({
    super.key,
    required this.media,
    required this.caption,
    required this.onZoomChanged,
  });

  final ChatMessageMedia media;
  final String caption;
  final ValueChanged<bool> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    final url = media.url ?? media.thumbnailUrl ?? '';
    final w = media.width;
    final h = media.height;
    final hasSize = w != null && h != null && w > 0 && h > 0;
    final image = _ZoomableImage(url: url, onZoomChanged: onZoomChanged);

    if (caption.isEmpty) return image;

    // The caption sits 16px under the photo, as in the mock, so the photo is
    // sized to its own ratio when the API gave one.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child:
              hasSize
                  ? AspectRatio(aspectRatio: w / h, child: image)
                  : image,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              caption,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  static const _doubleTapScale = 2.5;
  static const _maxScale = 4.0;

  final _transformation = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  bool get _isZoomed => _transformation.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_isZoomed) {
      _transformation.value = Matrix4.identity();
    } else {
      final dx = -_doubleTapPosition.dx * (_doubleTapScale - 1);
      final dy = -_doubleTapPosition.dy * (_doubleTapScale - 1);
      _transformation.value = Matrix4.diagonal3Values(
        _doubleTapScale,
        _doubleTapScale,
        1,
      )..setTranslationRaw(dx, dy, 0);
    }
    widget.onZoomChanged(_isZoomed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transformation,
        minScale: 1,
        maxScale: _maxScale,
        onInteractionEnd: (_) => widget.onZoomChanged(_isZoomed),
        child: SizedBox.expand(
          child:
              widget.url.isEmpty
                  ? const _Broken()
                  : CachedNetworkImageWidget(
                    imageUrl: widget.url,
                    fit: BoxFit.contain,
                    placeholder: const ChatMediaSkeleton(onDark: true),
                    errorWidget: const _Broken(),
                  ),
        ),
      ),
    );
  }
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(AppAssets.image, color: AppColors.grey500, size: 32),
    );
  }
}

/// One video: poster until it loads, then tap to play or pause, a scrubber,
/// `0:16 / 0:42` and mute. Plays only while its page is the current one.
class _VideoPage extends StatefulWidget {
  const _VideoPage({
    super.key,
    required this.media,
    required this.isActive,
    this.controllerFactory,
  });

  final ChatMessageMedia media;
  final bool isActive;
  final VideoPlayerController Function(Uri url)? controllerFactory;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && _controller == null) unawaited(_start());
    if (!widget.isActive) _controller?.pause();
  }

  Future<void> _start() async {
    final url = widget.media.url;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) {
      setState(() => _failed = true);
      return;
    }
    final controller =
        widget.controllerFactory?.call(uri) ??
        VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(_muted ? 0 : 1);
      if (widget.isActive) await controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final poster = widget.media.thumbnailUrl;
    final duration =
        ready
            ? c.value.duration
            : Duration(milliseconds: widget.media.durationMs ?? 0);
    final position = ready ? c.value.position : Duration.zero;
    final playing = ready && c.value.isPlaying;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (ready)
                  AspectRatio(
                    aspectRatio:
                        c.value.aspectRatio <= 0 ? 16 / 9 : c.value.aspectRatio,
                    child: VideoPlayer(c),
                  )
                else if (poster != null && poster.isNotEmpty)
                  CachedNetworkImageWidget(
                    imageUrl: poster,
                    fit: BoxFit.contain,
                    placeholder: const ChatMediaSkeleton(onDark: true),
                    errorWidget: const _Broken(),
                  )
                else if (!_failed)
                  const ChatMediaSkeleton(onDark: true),
                if (_failed)
                  const _Broken()
                else if (!ready)
                  const ChatVideoPlayBadge()
                else
                  AnimatedOpacity(
                    opacity: playing ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: ChatVideoPlayBadge(
                      icon: playing ? AppAssets.pause : AppAssets.play,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.white,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  value:
                      duration.inMilliseconds <= 0
                          ? 0
                          : (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0.0, 1.0),
                  onChanged:
                      ready
                          ? (value) => c.seekTo(
                            Duration(
                              milliseconds:
                                  (duration.inMilliseconds * value).round(),
                            ),
                          )
                          : null,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${formatChatDuration(position)} / ${formatChatDuration(duration)}',
                    style: const TextStyle(
                      color: AppColors.grey500,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip:
                        _muted
                            ? context.l10n.group_chat_media_unmute
                            : context.l10n.group_chat_media_mute,
                    onPressed: _toggleMute,
                    icon: Icon(
                      _muted ? AppAssets.speakerSimpleX : AppAssets.speakerSimpleHigh,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
