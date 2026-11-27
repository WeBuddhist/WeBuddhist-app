import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_local_media_cache.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_message_media_preview.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_badges.dart';
import 'package:flutter_pecha/core/utils/network_image_utils.dart';

/// Hero tag shared by a thread tile and its page in the viewer.
String chatMediaHeroTag(String messageId, String mediaId) =>
    'chat-media-$messageId-$mediaId';

/// Width over height of a single photo in the thread, from its pixel size,
/// clamped so a panorama or a tall screenshot stays a sensible bubble.
double chatMediaSingleAspect({int? width, int? height, bool isVideo = false}) {
  if (isVideo) return ChatMediaGrid.heroRatio;
  if (width != null && height != null && width > 0 && height > 0) {
    return (width / height).clamp(0.55, 1.8);
  }
  return 4 / 3;
}

/// Layout shared by sent and pending media: one, two side by side, or a hero
/// over two squares, a fourth item onward folded into "+N" on the third
/// tile, as in the "Sent – 3 photos" frame. Using one widget for both keeps
/// a message the same shape when its upload finishes.
class ChatMediaGrid extends StatelessWidget {
  const ChatMediaGrid({
    super.key,
    required this.count,
    required this.tileBuilder,
    this.singleAspectRatio = 4 / 3,
  });

  final int count;

  /// Builds tile [index]. [coveredByCount] is true for the tile under "+N",
  /// which should leave out its own badges.
  final Widget Function(int index, bool coveredByCount) tileBuilder;

  /// Used when [count] is one.
  final double singleAspectRatio;

  static const maxVisible = 3;
  static const gap = 3.0;
  static const radius = BorderRadius.all(Radius.circular(10));

  /// 232 x 160 hero and 114.5 squares inside the 240 bubble.
  static const heroRatio = 232 / 160;
  static const rowRatio = 232 / 114.5;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return switch (count) {
      1 => AspectRatio(aspectRatio: singleAspectRatio, child: _tile(0)),
      2 => AspectRatio(
        aspectRatio: rowRatio,
        child: Row(children: _row([0, 1])),
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(aspectRatio: heroRatio, child: _tile(0)),
          const SizedBox(height: gap),
          AspectRatio(
            aspectRatio: rowRatio,
            child: Row(children: _row([1, 2])),
          ),
        ],
      ),
    };
  }

  List<Widget> _row(List<int> indexes) {
    return [
      for (var i = 0; i < indexes.length; i++) ...[
        if (i > 0) const SizedBox(width: gap),
        Expanded(child: _tile(indexes[i])),
      ],
    ];
  }

  Widget _tile(int index) {
    final hidden = count - maxVisible;
    final covered = index == maxVisible - 1 && hidden > 0;
    final tile = tileBuilder(index, covered);
    return ClipRRect(
      borderRadius: radius,
      child:
          covered
              ? Stack(
                fit: StackFit.expand,
                children: [tile, IgnorePointer(child: _countScrim(hidden))],
              )
              : tile,
    );
  }

  Widget _countScrim(int hidden) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Text(
          '+$hidden',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// In-thread grid for chat message photos and video posters.
class ChatMessageMediaBubble extends StatelessWidget {
  const ChatMessageMediaBubble({
    super.key,
    required this.media,
    required this.isDark,
    this.messageId,
    this.onTapMedia,
  });

  final List<ChatMessageMedia> media;
  final bool isDark;

  /// Scopes the Hero tags; null leaves the tiles without a Hero.
  final String? messageId;

  /// Opens the viewer at the tapped item. Null while the thread is selecting,
  /// so a tap toggles the row instead.
  final ValueChanged<int>? onTapMedia;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final first = media.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ChatMediaGrid(
        count: media.length,
        singleAspectRatio: chatMediaSingleAspect(
          width: first.width,
          height: first.height,
          isVideo: chatMediaIsVideo(first.mediaType),
        ),
        tileBuilder: _tile,
      ),
    );
  }

  Widget _tile(int index, bool coveredByCount) {
    final item = media[index];
    final url = _displayUrl(item);
    final local = ChatLocalMediaCache.instance[item.id];

    Widget content;
    if ((url == null || url.isEmpty) && local == null) {
      content = _placeholder(item, withChrome: !coveredByCount);
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          if (url == null || url.isEmpty)
            _localImage(local!.image, item)
          else
            CachedNetworkImageWidget(
              key: networkImageKey(url),
              imageUrl: url,
              fit: BoxFit.cover,
              // A photo this device just sent paints from its own file, which
              // the pending bubble already decoded, so the swap is invisible.
              placeholder:
                  local != null
                      ? _localImage(local.image, item)
                      : _loadingFill(),
              fadeInDuration:
                  local != null ? Duration.zero : const Duration(milliseconds: 150),
              errorWidget:
                  local != null
                      ? _localImage(local.image, item)
                      : _placeholder(item, withChrome: false),
            ),
          if (chatMediaIsVideo(item.mediaType))
            ..._videoChrome(item, coveredByCount),
        ],
      );
    }

    final id = messageId;
    if (id != null && index < ChatMediaGrid.maxVisible) {
      content = Hero(
        tag: chatMediaHeroTag(id, item.id),
        child: content,
      );
    }

    final onTap = onTapMedia;
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: content,
    );
  }

  Widget _localImage(File file, ChatMessageMedia item) {
    return Image(
      image: chatLocalTileProvider(file),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _loadingFill(),
    );
  }

  /// A calm flat fill, no shimmer, while a tile downloads.
  Widget _loadingFill() {
    return ColoredBox(color: isDark ? AppColors.grey800 : AppColors.grey100);
  }

  /// Play button and, when known, the `0:42` badge over a video poster.
  List<Widget> _videoChrome(ChatMessageMedia item, bool coveredByCount) {
    if (coveredByCount) return const [];
    final ms = item.durationMs;
    return [
      const ChatVideoPlayBadge(),
      if (ms != null && ms > 0)
        Positioned(
          left: 8,
          bottom: 8,
          child: ChatDurationBadge(duration: Duration(milliseconds: ms)),
        ),
    ];
  }

  /// [withChrome] off when the caller already draws the play button.
  Widget _placeholder(ChatMessageMedia item, {bool withChrome = true}) {
    final isVideo = chatMediaIsVideo(item.mediaType);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: isDark ? AppColors.grey800 : AppColors.grey100,
          child:
              isVideo
                  ? null
                  : Center(
                    child: Icon(
                      AppAssets.image,
                      color: isDark ? AppColors.grey500 : AppColors.grey600,
                      size: 28,
                    ),
                  ),
        ),
        if (isVideo && withChrome) ..._videoChrome(item, false),
      ],
    );
  }

  String? _displayUrl(ChatMessageMedia item) {
    final thumb = item.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) return thumb;
    return item.url;
  }
}
