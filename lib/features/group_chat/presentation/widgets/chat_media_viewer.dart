import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/cache/app_image_cache_manager.dart';
import 'package:flutter_pecha/core/cache/chat_video_cache_manager.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/utils/network_image_utils.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_local_media_cache.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_limits.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_saver.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_message_media_preview.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_badges.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_message_media_bubble.dart';
import 'package:video_player/video_player.dart';

typedef ChatMediaSaver =
    Future<ChatMediaSaveOutcome> Function({
      required String url,
      required bool isVideo,
    });

/// Full-screen photos and video from one chat message, per the "Image viewer"
/// and "Video player" frames: close, sender and time, download. Reporting is
/// on long-press in the thread, not here.
///
/// Opens with a Hero from the thread tile, paints the thumbnail the thread
/// already has while the full image loads, and closes on a swipe down.
class ChatMediaViewer extends StatefulWidget {
  const ChatMediaViewer({
    super.key,
    required this.media,
    required this.senderName,
    required this.sentAt,
    this.caption = '',
    this.initialIndex = 0,
    this.messageId,
    this.saver,
    this.videoControllerFactory,
  });

  final List<ChatMessageMedia> media;
  final String senderName;
  final DateTime sentAt;

  /// The message body, shown over the bottom of a photo.
  final String caption;
  final int initialIndex;

  /// Matches the thread tiles' Hero tags; null opens without a Hero.
  final String? messageId;

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
    String? messageId,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'chat-media-viewer'),
        // See-through, so a swipe down reveals the thread as it fades.
        opaque: false,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder:
            (_, _, _) => ChatMediaViewer(
              media: media,
              senderName: senderName,
              sentAt: sentAt,
              caption: caption,
              initialIndex: initialIndex,
              messageId: messageId,
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

class _ChatMediaViewerState extends State<ChatMediaViewer>
    with SingleTickerProviderStateMixin {
  /// How far a swipe must travel, or how fast, to close the viewer.
  static const _dismissDistance = 110.0;
  static const _dismissVelocity = 800.0;

  late final PageController _pages;
  late final AnimationController _settle;
  final _drag = ValueNotifier<double>(0);
  final _prefetched = <String>{};
  double _settleFrom = 0;
  late int _index;
  bool _zoomed = false;
  bool _saving = false;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.media.length - 1);
    _pages = PageController(initialPage: _index);
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
      _drag.value =
          _settleFrom * (1 - Curves.easeOut.transform(_settle.value));
    });
    _prefetchAround(_index);
  }

  @override
  void dispose() {
    _pages.dispose();
    _settle.dispose();
    _drag.dispose();
    super.dispose();
  }

  ChatMessageMedia get _current => widget.media[_index];

  String? _heroTag(ChatMessageMedia item) {
    final id = widget.messageId;
    return id == null ? null : chatMediaHeroTag(id, item.id);
  }

  /// Warms the disk cache for the photos either side, so a swipe lands on a
  /// sharp image. Disk only: decoding them now would cost memory for pages
  /// that may never be shown.
  void _prefetchAround(int index) {
    for (final i in [index - 1, index + 1]) {
      if (i < 0 || i >= widget.media.length) continue;
      final item = widget.media[i];
      if (chatMediaIsVideo(item.mediaType)) continue;
      final url = item.url;
      if (url == null || url.isEmpty || !_prefetched.add(url)) continue;
      unawaited(
        appImageCacheManager
            .getSingleFile(url, key: stableNetworkImageCacheKey(url))
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  void _setChrome(bool visible) {
    if (visible != _chromeVisible && mounted) {
      setState(() => _chromeVisible = visible);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _settle.stop();
    _drag.value += details.delta.dy;
  }

  void _onDragEnd(DragEndDetails details) {
    final dy = _drag.value;
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (dy.abs() > _dismissDistance || velocity.abs() > _dismissVelocity) {
      Navigator.of(context).pop();
      return;
    }
    _settleFrom = dy;
    _settle.forward(from: 0);
  }

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

    final pages = PageView.builder(
      controller: _pages,
      physics:
          _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
      itemCount: total,
      onPageChanged: (index) {
        setState(() {
          _index = index;
          _zoomed = false;
        });
        _prefetchAround(index);
      },
      itemBuilder: (context, index) {
        final item = widget.media[index];
        if (chatMediaIsVideo(item.mediaType)) {
          return _VideoPage(
            key: ValueKey('video-${item.id}'),
            media: item,
            heroTag: _heroTag(item),
            isActive: index == _index,
            chromeVisible: _chromeVisible,
            onChromeChanged: _setChrome,
            controllerFactory: widget.videoControllerFactory,
          );
        }
        return _PhotoPage(
          key: ValueKey('photo-${item.id}'),
          media: item,
          heroTag: _heroTag(item),
          caption: caption,
          chromeVisible: _chromeVisible,
          onTap: () => _setChrome(!_chromeVisible),
          onZoomChanged: (zoomed) {
            if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<double>(
        valueListenable: _drag,
        builder: (context, dy, child) {
          final pull = (dy.abs() / 320).clamp(0.0, 1.0);
          return ColoredBox(
            color: Colors.black.withValues(alpha: 1 - pull * 0.9),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(scale: 1 - pull * 0.2, child: child),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _Chrome(
                    visible: _chromeVisible && dy == 0,
                    child: _Header(
                      title: widget.senderName,
                      subtitle: subtitle,
                      saving: _saving,
                      onClose: () => Navigator.of(context).pop(),
                      onDownload: _download,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: GestureDetector(
          // Zoomed photos pan instead; a swipe down closes only at 1x.
          onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
          onVerticalDragEnd: _zoomed ? null : _onDragEnd,
          child: pages,
        ),
      ),
    );
  }
}

/// Fades the header, caption and video controls together.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: child,
      ),
    );
  }
}

/// Black-to-clear fade behind overlaid chrome so white text always reads.
BoxDecoration _scrim({required bool top}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: top ? Alignment.topCenter : Alignment.bottomCenter,
      end: top ? Alignment.bottomCenter : Alignment.topCenter,
      colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
    ),
  );
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
    return DecoratedBox(
      decoration: _scrim(top: true),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
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
        ),
      ),
    );
  }
}

/// Width over height from the API, when it gave both.
double? _mediaAspect(ChatMessageMedia media) {
  final w = media.width;
  final h = media.height;
  if (w == null || h == null || w <= 0 || h <= 0) return null;
  return w / h;
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({
    super.key,
    required this.media,
    required this.heroTag,
    required this.caption,
    required this.chromeVisible,
    required this.onTap,
    required this.onZoomChanged,
  });

  final ChatMessageMedia media;
  final String? heroTag;
  final String caption;
  final bool chromeVisible;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  /// Room kept for up to six caption lines before it falls back to the
  /// bottom of the screen.
  static const _captionRoom = 150.0;

  @override
  Widget build(BuildContext context) {
    final image = _ZoomableImage(
      media: media,
      heroTag: heroTag,
      onTap: onTap,
      onZoomChanged: onZoomChanged,
    );
    if (caption.isEmpty) return image;

    final text = Text(
      caption,
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
      // Against the right edge, as in the "Image viewer" mock.
      textAlign: TextAlign.end,
      style: const TextStyle(color: Colors.white, fontSize: 16),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final aspect = _mediaAspect(media);
        // Where the centred photo ends, so the caption hangs 16px under it,
        // as in the "Image viewer" mock.
        final photoHeight =
            aspect == null
                ? size.height
                : (size.width / aspect).clamp(0.0, size.height);
        final photoBottom = (size.height + photoHeight) / 2;
        final fitsUnder = photoBottom + 16 + _captionRoom <= size.height;

        final Widget body =
            fitsUnder
                ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: text,
                )
                // A tall photo leaves no room under it: lay the caption over
                // its bottom edge on a scrim instead.
                : DecoratedBox(
                  decoration: _scrim(top: false),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                      child: text,
                    ),
                  ),
                );

        return Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(
              left: 0,
              right: 0,
              top: fitsUnder ? photoBottom : null,
              bottom: fitsUnder ? null : 0,
              // Fades with the header on tap.
              child: _Chrome(visible: chromeVisible, child: body),
            ),
          ],
        );
      },
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.media,
    required this.heroTag,
    required this.onTap,
    required this.onZoomChanged,
  });

  final ChatMessageMedia media;
  final String? heroTag;
  final VoidCallback onTap;
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
    final aspect = _mediaAspect(widget.media);
    Widget image = _ProgressiveImage(
      media: widget.media,
      fit: aspect == null ? BoxFit.contain : BoxFit.cover,
    );
    final tag = widget.heroTag;
    if (tag != null) image = Hero(tag: tag, child: image);
    // Sized to the photo, so the Hero flies to exactly where it lands.
    image = Center(
      child:
          aspect == null
              ? SizedBox.expand(child: image)
              : AspectRatio(aspectRatio: aspect, child: image),
    );

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transformation,
        minScale: 1,
        maxScale: _maxScale,
        onInteractionEnd: (_) => widget.onZoomChanged(_isZoomed),
        child: SizedBox.expand(child: image),
      ),
    );
  }
}

/// The thumbnail at once, this device's own file when it sent the photo, and
/// the full image fading in over both. A small ring shows the download, never
/// a shimmer over the whole screen.
class _ProgressiveImage extends StatelessWidget {
  const _ProgressiveImage({required this.media, required this.fit});

  final ChatMessageMedia media;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final thumb = media.thumbnailUrl;
    final full = media.url;
    final local = ChatLocalMediaCache.instance[media.id];
    final hasThumb = thumb != null && thumb.isNotEmpty;
    final hasFull = full != null && full.isNotEmpty && full != thumb;
    final hasPreview = hasThumb || local != null;

    if (!hasPreview && !hasFull) return const _Broken();

    final screenPx =
        (MediaQuery.sizeOf(context).longestSide *
                MediaQuery.devicePixelRatioOf(context))
            .round();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasThumb)
          CachedNetworkImageWidget(
            key: networkImageKey(thumb),
            imageUrl: thumb,
            fit: fit,
            fadeInDuration: Duration.zero,
            placeholder: const SizedBox.shrink(),
            errorWidget: const SizedBox.shrink(),
          ),
        if (local != null)
          Image(
            image: ResizeImage(
              FileImage(local.image),
              width: screenPx,
              policy: ResizeImagePolicy.fit,
            ),
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (hasFull)
          CachedNetworkImageWidget(
            key: networkImageKey(full),
            imageUrl: full,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 180),
            progressIndicatorBuilder:
                (_, _, progress) => _DelayedRing(progress: progress.progress),
            errorWidget:
                hasPreview ? const SizedBox.shrink() : const _Broken(),
          ),
      ],
    );
  }
}

/// A small download ring, held back a moment so a quick load never flashes
/// one.
class _DelayedRing extends StatefulWidget {
  const _DelayedRing({this.progress});

  final double? progress;

  @override
  State<_DelayedRing> createState() => _DelayedRingState();
}

class _DelayedRingState extends State<_DelayedRing> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: _Spinner(progress: widget.progress),
      ),
    );
  }
}

/// White ring on a dark disc, readable over any photo.
class _Spinner extends StatelessWidget {
  const _Spinner({this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 2.5,
        strokeCap: StrokeCap.round,
        color: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.25),
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

/// One video. The poster stays up until the first frame really plays, so
/// there is no black flash; a spinner shows while it buffers. Tap shows or
/// hides the controls, which hide by themselves while it plays. Plays only
/// while its page is the current one, from the disk cache when it can.
class _VideoPage extends StatefulWidget {
  const _VideoPage({
    super.key,
    required this.media,
    required this.heroTag,
    required this.isActive,
    required this.chromeVisible,
    required this.onChromeChanged,
    this.controllerFactory,
  });

  final ChatMessageMedia media;
  final String? heroTag;
  final bool isActive;
  final bool chromeVisible;
  final ValueChanged<bool> onChromeChanged;
  final VideoPlayerController Function(Uri url)? controllerFactory;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with WidgetsBindingObserver {
  static const _autoHide = Duration(seconds: 3);

  VideoPlayerController? _controller;
  Timer? _hideTimer;
  bool _ready = false;
  bool _firstFrame = false;
  bool _failed = false;
  bool _playing = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && _controller == null && !_failed) {
      unawaited(_start());
    }
    if (!widget.isActive) _controller?.pause();
    if (widget.chromeVisible && !oldWidget.chromeVisible) _scheduleHide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _controller?.removeListener(_onValue);
    _controller?.dispose();
    super.dispose();
  }

  Future<VideoPlayerController> _makeController(String url, Uri uri) async {
    final factory = widget.controllerFactory;
    if (factory != null) return factory(uri);
    final key = stableNetworkImageCacheKey(url);
    try {
      final cached = await chatVideoCacheManager.getFileFromCache(key);
      final file = cached?.file;
      if (file != null && await file.exists()) {
        return VideoPlayerController.file(File(file.path));
      }
    } catch (_) {}
    final local = ChatLocalMediaCache.instance[widget.media.id]?.video;
    if (local != null && await local.exists()) {
      return VideoPlayerController.file(local);
    }
    return VideoPlayerController.networkUrl(uri);
  }

  /// After a streamed start, keeps a copy so the next play is instant.
  void _cacheForNextTime(String url) {
    if (widget.controllerFactory != null) return;
    if (widget.media.fileSizeBytes > kChatMaxVideoBytes) return;
    unawaited(
      chatVideoCacheManager
          .downloadFile(url, key: stableNetworkImageCacheKey(url))
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  Future<void> _start() async {
    final url = widget.media.url;
    final uri = url == null ? null : Uri.tryParse(url);
    if (url == null || uri == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _failed = false);
    final controller = await _makeController(url, uri);
    if (!mounted) {
      unawaited(controller.dispose());
      return;
    }
    _controller = controller;
    controller.addListener(_onValue);
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(_muted ? 0 : 1);
      if (controller.dataSourceType == DataSourceType.network) {
        _cacheForNextTime(url);
      }
      if (widget.isActive) await controller.play();
    } catch (_) {
      if (mounted) _fail();
    }
  }

  void _fail() {
    final c = _controller;
    _controller = null;
    c?.removeListener(_onValue);
    unawaited(c?.dispose());
    setState(() {
      _failed = true;
      _ready = false;
      _firstFrame = false;
      _playing = false;
    });
  }

  Future<void> _retry() async {
    if (_controller != null) return;
    await _start();
  }

  /// Rebuilds the page only when what it draws changes; the scrubber and the
  /// time listen to the controller on their own.
  void _onValue() {
    final c = _controller;
    if (c == null || !mounted) return;
    final v = c.value;
    if (v.hasError) {
      _fail();
      return;
    }
    final ready = v.isInitialized;
    final firstFrame = _firstFrame || (ready && v.position > Duration.zero);
    final playing = v.isPlaying;
    if (ready != _ready || firstFrame != _firstFrame || playing != _playing) {
      final startedPlaying = playing && !_playing;
      setState(() {
        _ready = ready;
        _firstFrame = firstFrame;
        _playing = playing;
      });
      if (startedPlaying) _scheduleHide();
      if (!playing) _hideTimer?.cancel();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing) return;
    _hideTimer = Timer(_autoHide, () {
      if (mounted && _playing) widget.onChromeChanged(false);
    });
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
    _scheduleHide();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final poster = widget.media.thumbnailUrl;
    final aspect =
        (_ready && c != null && c.value.aspectRatio > 0)
            ? c.value.aspectRatio
            : _mediaAspect(widget.media) ?? 16 / 9;

    Widget frame = Stack(
      fit: StackFit.expand,
      children: [
        if (_ready && c != null) VideoPlayer(c),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _firstFrame ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child:
                poster != null && poster.isNotEmpty
                    ? CachedNetworkImageWidget(
                      key: networkImageKey(poster),
                      imageUrl: poster,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      placeholder: const ColoredBox(color: Colors.black),
                      errorWidget: const ColoredBox(color: Colors.black),
                    )
                    : const ColoredBox(color: Colors.black),
          ),
        ),
      ],
    );
    final tag = widget.heroTag;
    if (tag != null) frame = Hero(tag: tag, child: frame);

    final showsCenter = widget.chromeVisible || !_playing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onChromeChanged(!widget.chromeVisible),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: AspectRatio(aspectRatio: aspect, child: frame)),
          Center(child: _centerControl(c, showsCenter)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Chrome(
              visible: widget.chromeVisible,
              child: DecoratedBox(
                decoration: _scrim(top: false),
                child: SafeArea(
                  top: false,
                  child:
                      c != null && _ready
                          ? _VideoControls(
                            controller: c,
                            muted: _muted,
                            onToggleMute: _toggleMute,
                            onScrub: _scheduleHide,
                          )
                          : _VideoControls.idle(
                            duration: Duration(
                              milliseconds: widget.media.durationMs ?? 0,
                            ),
                            muted: _muted,
                            onToggleMute: _toggleMute,
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerControl(VideoPlayerController? c, bool visible) {
    if (_failed) {
      return Semantics(
        button: true,
        label: context.l10n.group_chat_retry,
        child: GestureDetector(
          onTap: _retry,
          child: const ChatVideoPlayBadge(
            icon: AppAssets.arrowCounterClockwise,
          ),
        ),
      );
    }
    if (c == null || !_ready) return const _Spinner();
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        if (value.isBuffering && value.isPlaying) return const _Spinner();
        return _Chrome(
          visible: visible,
          child: GestureDetector(
            onTap: _togglePlay,
            child: ChatVideoPlayBadge(
              icon: value.isPlaying ? AppAssets.pause : AppAssets.play,
            ),
          ),
        );
      },
    );
  }
}

/// Scrubber with the buffered range, `0:16 / 0:42` and mute. Listens to the
/// controller itself, so playback never rebuilds the page around it.
class _VideoControls extends StatefulWidget {
  const _VideoControls({
    required VideoPlayerController this.controller,
    required this.muted,
    required this.onToggleMute,
    required this.onScrub,
  }) : idleDuration = Duration.zero;

  const _VideoControls.idle({
    required Duration duration,
    required this.muted,
    required this.onToggleMute,
  }) : controller = null,
       idleDuration = duration,
       onScrub = null;

  final VideoPlayerController? controller;
  final Duration idleDuration;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback? onScrub;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  /// The thumb's value while dragging; the video seeks once, on release.
  double? _dragValue;
  bool _wasPlaying = false;

  double _fraction(Duration part, Duration whole) {
    if (whole.inMilliseconds <= 0) return 0;
    return (part.inMilliseconds / whole.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration _bufferedEnd(VideoPlayerValue value) {
    var end = Duration.zero;
    for (final range in value.buffered) {
      if (range.end > end) end = range.end;
    }
    return end;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c == null) {
      return _layout(
        context,
        value: 0,
        buffered: 0,
        position: Duration.zero,
        duration: widget.idleDuration,
        onChanged: null,
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        final duration = value.duration;
        final drag = _dragValue;
        final position =
            drag != null
                ? Duration(
                  milliseconds: (duration.inMilliseconds * drag).round(),
                )
                : value.position;
        return _layout(
          context,
          value: drag ?? _fraction(value.position, duration),
          buffered: _fraction(_bufferedEnd(value), duration),
          position: position,
          duration: duration,
          onChangeStart: (_) {
            _wasPlaying = value.isPlaying;
            c.pause();
          },
          onChanged: (v) => setState(() => _dragValue = v),
          onChangeEnd: (v) async {
            await c.seekTo(
              Duration(milliseconds: (duration.inMilliseconds * v).round()),
            );
            if (_wasPlaying) await c.play();
            if (mounted) setState(() => _dragValue = null);
            widget.onScrub?.call();
          },
        );
      },
    );
  }

  Widget _layout(
    BuildContext context, {
    required double value,
    required double buffered,
    required Duration position,
    required Duration duration,
    required ValueChanged<double>? onChanged,
    ValueChanged<double>? onChangeStart,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: Colors.white,
              secondaryActiveTrackColor: Colors.white.withValues(alpha: 0.5),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
              disabledActiveTrackColor: Colors.white,
              disabledInactiveTrackColor: Colors.white.withValues(alpha: 0.25),
              disabledThumbColor: Colors.white,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              secondaryTrackValue: buffered,
              onChangeStart: onChangeStart,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${formatChatDuration(position)} / ${formatChatDuration(duration)}',
                style: const TextStyle(color: AppColors.grey500, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                tooltip:
                    widget.muted
                        ? context.l10n.group_chat_media_unmute
                        : context.l10n.group_chat_media_mute,
                onPressed: widget.onToggleMute,
                icon: Icon(
                  widget.muted
                      ? AppAssets.speakerSimpleX
                      : AppAssets.speakerSimpleHigh,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
