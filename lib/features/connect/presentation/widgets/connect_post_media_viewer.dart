import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/connect/domain/entities/connect_post.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_post_like_actions.dart';
import 'package:flutter_pecha/features/connect/presentation/utils/connect_like_utils.dart';
import 'package:flutter_pecha/features/connect/presentation/utils/connect_post_share.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen photo viewer for a post: swipe between photos, pinch or
/// double-tap to zoom, swipe down to close.
class ConnectPostMediaViewer extends StatefulWidget {
  const ConnectPostMediaViewer({
    super.key,
    required this.media,
    this.initialIndex = 0,
    this.title,
    this.actions,
  });

  final List<ConnectPostMedia> media;
  final int initialIndex;

  /// Shown above the zoom hint, usually the group name.
  final String? title;

  final Widget? actions;

  static Future<void> show(
    BuildContext context, {
    required List<ConnectPostMedia> media,
    int initialIndex = 0,
    String? title,
    Widget? actions,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        // The scaffold paints the black, so it can fade while dragging down.
        barrierColor: Colors.transparent,
        pageBuilder:
            (_, __, ___) => ConnectPostMediaViewer(
              media: media,
              initialIndex: initialIndex,
              title: title,
              actions: actions,
            ),
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<ConnectPostMediaViewer> createState() => _ConnectPostMediaViewerState();
}

class _ConnectPostMediaViewerState extends State<ConnectPostMediaViewer>
    with SingleTickerProviderStateMixin {
  /// A drag down past this distance, or flung faster, closes the viewer.
  static const _dismissDistance = 120.0;
  static const _dismissVelocity = 700.0;

  /// Drag distance at which the background and chrome are fully faded.
  static const _fadeDistance = 300.0;

  late final PageController _controller;
  late final AnimationController _settle;
  late int _index;
  bool _zoomed = false;
  bool _dismissing = false;
  double _dragDy = 0;
  double _settleFrom = 0;

  double get _dragProgress => (_dragDy / _fadeDistance).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.media.length - 1);
    _controller = PageController(initialPage: _index);
    // Built here, not lazily: a lazy one would first be made in dispose().
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(
      () => setState(() => _dragDy = _settleFrom * (1 - _settle.value)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    _settle.stop();
    setState(() => _dragDy = math.max(0, _dragDy + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDy > _dismissDistance || velocity > _dismissVelocity) {
      // Stay where the finger left the photo while the route fades out.
      _dismissing = true;
      Navigator.of(context).maybePop();
      return;
    }
    _settleBack();
  }

  void _settleBack() {
    if (_dismissing || _dragDy == 0) return;
    _settleFrom = _dragDy;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title?.trim() ?? '';
    final actions = widget.actions;
    final chromeOpacity = 1 - _dragProgress;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1 - _dragProgress * 0.8),
      body: SafeArea(
        child: Column(
          children: [
            Opacity(
              opacity: chromeOpacity,
              child: SizedBox(
                height: 48,
                child: Stack(
                  children: [
                    if (widget.media.length > 1)
                      Center(
                        child: Text(
                          '${_index + 1} / ${widget.media.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip:
                            MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                        icon: const Icon(AppAssets.x, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              // Off while zoomed, so a drag pans the photo instead.
              child: GestureDetector(
                onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
                onVerticalDragEnd: _zoomed ? null : _onDragEnd,
                onVerticalDragCancel: _zoomed ? null : _settleBack,
                child: Transform.translate(
                  offset: Offset(0, _dragDy),
                  child: PageView.builder(
                    controller: _controller,
                    physics:
                        _zoomed
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                    itemCount: widget.media.length,
                    onPageChanged:
                        (index) => setState(() {
                          _index = index;
                          _zoomed = false;
                        }),
                    itemBuilder:
                        (context, index) => _ZoomableImage(
                          media: widget.media[index],
                          panEnabled: _zoomed,
                          onZoomChanged: (zoomed) {
                            if (zoomed != _zoomed) {
                              setState(() => _zoomed = zoomed);
                            }
                          },
                        ),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: chromeOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.connect_post_media_viewer_hint,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    if (actions != null) ...[
                      const SizedBox(height: 8),
                      actions,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.media,
    required this.panEnabled,
    required this.onZoomChanged,
  });

  final ConnectPostMedia media;

  /// Off at normal size, so a vertical drag reaches swipe-to-close.
  final bool panEnabled;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  static const _doubleTapScale = 2.5;
  static const _maxScale = 4.0;

  /// Longest decoded side; keeps a huge photo from taking hundreds of MB.
  static const _maxDecodeSide = 4096.0;

  final TransformationController _transformation = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  bool get _isZoomed => _transformation.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  int _decodeBound(double viewportPx) {
    return (viewportPx * _maxScale).clamp(1.0, _maxDecodeSide).round();
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
        panEnabled: widget.panEnabled,
        minScale: 1,
        maxScale: _maxScale,
        onInteractionEnd: (_) => widget.onZoomChanged(_isZoomed),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport =
                constraints.biggest * MediaQuery.devicePixelRatioOf(context);
            return SizedBox.expand(
              // Sharp at full zoom. The fit policy reads the real photo size,
              // so both sides stay bounded without stretching or upscaling.
              child: Image(
                image: ResizeImage(
                  widget.media.url.trim().cachedNetworkImageProvider,
                  width: _decodeBound(viewport.width),
                  height: _decodeBound(viewport.height),
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) => const Center(
                      child: Icon(
                        AppAssets.photoLibrary,
                        color: AppColors.grey500,
                      ),
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Like and share buttons for the viewer's dark footer.
///
/// Holds its own copy of the post and like state: the screen that opened the
/// viewer can be reused for another post or disposed while the viewer is open.
class ConnectPostMediaViewerActions extends ConsumerStatefulWidget {
  const ConnectPostMediaViewerActions({
    super.key,
    required this.post,
    this.includeUnfollowed = false,
    this.groupId,
    this.onLikeChanged,
    this.onComment,
  });

  /// The post as the opening screen currently shows it.
  final ConnectPost post;
  final bool includeUnfollowed;
  final String? groupId;

  /// Called after a like succeeds, even if the viewer has closed by then.
  final ValueChanged<ConnectPost>? onLikeChanged;

  /// Shows the post's comments. The viewer closes first, so this runs once
  /// the opening screen is back on top. Without it there is no comment button.
  final VoidCallback? onComment;

  @override
  ConsumerState<ConnectPostMediaViewerActions> createState() =>
      _ConnectPostMediaViewerActionsState();
}

class _ConnectPostMediaViewerActionsState
    extends ConsumerState<ConnectPostMediaViewerActions> {
  final ConnectOptimisticLikeState _likeState = ConnectOptimisticLikeState();
  late ConnectPost _post = widget.post;

  bool get _isLiked => _likeState.isLiked(_post.likedByMe);

  int get _likeCount => _likeState.likeCount(
    serverLikeCount: _post.likeCount,
    serverLikedByMe: _post.likedByMe,
  );

  @override
  void initState() {
    super.initState();
    final pending = ref
        .read(connectPostLikeActionsProvider)
        .pendingLike(widget.post.id);
    if (pending != null) _followPendingLike(pending);
  }

  /// Shows a request another surface started, and stays locked until it ends,
  /// so a new toggle cannot race it. That surface reports any failure.
  void _followPendingLike(ConnectPendingPostLike pending) {
    _post = _post.copyWith(
      likedByMe: !pending.wasLiked,
      likeCount: pending.optimisticLikeCount,
    );
    _likeState.isSubmitting = true;

    void settle({required bool succeeded}) {
      if (!mounted) return;
      setState(() {
        _likeState.isSubmitting = false;
        if (succeeded) return;
        _post = _post.copyWith(
          likedByMe: pending.wasLiked,
          likeCount: nextLikeCountAfterToggle(
            currentCount: pending.optimisticLikeCount,
            wasLiked: !pending.wasLiked,
          ),
        );
      });
    }

    pending.result.then(
      (result) => settle(succeeded: result.isSuccess),
      onError: (Object _) => settle(succeeded: false),
    );
  }

  Future<void> _toggleLike() async {
    if (_likeState.isSubmitting ||
        ref.read(connectPostLikeActionsProvider).pendingLike(_post.id) !=
            null) {
      return;
    }

    final authState = ref.read(authProvider);
    if (authState.isGuest || !authState.isLoggedIn) {
      LoginDrawer.show(context, ref, useRootNavigator: true);
      return;
    }

    final wasLiked = _isLiked;
    final onLikeChanged = widget.onLikeChanged;
    setState(() => _likeState.beginToggle(wasLiked));

    final result = await ref
        .read(connectPostLikeActionsProvider)
        .toggleLike(
          post: _post,
          wasLiked: wasLiked,
          optimisticLikeCount: _likeCount,
          includeUnfollowed: widget.includeUnfollowed,
          groupId: widget.groupId,
        );

    if (result.isSuccess) onLikeChanged?.call(result.updatedPost!);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _likeState.revert(wasLiked));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasLiked
                ? context.l10n.connect_failed_unlike_post_error
                : context.l10n.connect_failed_like_post_error,
          ),
        ),
      );
      return;
    }

    setState(() {
      _likeState.commitSuccess(
        serverLikeCount: _post.likeCount,
        serverLikedByMe: _post.likedByMe,
      );
      _post = result.updatedPost!;
    });
  }

  void _openComments() {
    final onComment = widget.onComment;
    Navigator.of(context).pop();
    onComment?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = _isLiked;
    final likeCount = _likeCount;

    return Row(
      children: [
        _FooterCountButton(
          icon: isLiked ? AppAssets.heartFill : AppAssets.heart,
          iconColor: isLiked ? AppColors.error : Colors.white,
          count: likeCount,
          onTap: _likeState.isSubmitting ? null : _toggleLike,
        ),
        if (widget.onComment != null) ...[
          const SizedBox(width: 12),
          _FooterCountButton(
            icon: AppAssets.chatCircle,
            count: _post.commentCount,
            onTap: _openComments,
          ),
        ],
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => shareConnectPost(context, ref, _post),
          icon: const Icon(
            AppAssets.readerShare,
            size: 20,
            color: Colors.white,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// An icon with an optional count, styled for the viewer's dark footer.
class _FooterCountButton extends StatelessWidget {
  const _FooterCountButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final Color iconColor;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Transform.translate(
                offset: const Offset(0, 1),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
