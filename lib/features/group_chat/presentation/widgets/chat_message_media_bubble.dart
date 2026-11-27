import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_message_media_preview.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/chat_media_badges.dart';
import 'package:flutter_pecha/core/utils/network_image_utils.dart';

/// In-thread grid for chat message photos and video posters.
class ChatMessageMediaBubble extends StatelessWidget {
  const ChatMessageMediaBubble({
    super.key,
    required this.media,
    required this.isDark,
    this.onTapMedia,
  });

  final List<ChatMessageMedia> media;
  final bool isDark;

  /// Opens the viewer at the tapped item. Null while the thread is selecting,
  /// so a tap toggles the row instead.
  final ValueChanged<int>? onTapMedia;

  /// One hero over two squares; a fourth item onward folds into "+N" on
  /// the third tile, as in the "Sent – 3 photos" frame.
  static const maxVisible = 3;
  static const gap = 3.0;
  static const radius = BorderRadius.all(Radius.circular(10));

  /// 232 x 160 hero and 114.5 squares inside the 240 bubble.
  static const _heroRatio = 232 / 160;
  static const _rowRatio = 232 / 114.5;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final grid = switch (media.length) {
      1 => _single(media.first),
      2 => AspectRatio(
        aspectRatio: _rowRatio,
        child: Row(children: _row([0, 1])),
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(aspectRatio: _heroRatio, child: _tile(0)),
          const SizedBox(height: gap),
          AspectRatio(
            aspectRatio: _rowRatio,
            child: Row(children: _row([1, 2])),
          ),
        ],
      ),
    };

    return Padding(padding: const EdgeInsets.only(bottom: 4), child: grid);
  }

  List<Widget> _row(List<int> indexes) {
    return [
      for (var i = 0; i < indexes.length; i++) ...[
        if (i > 0) const SizedBox(width: gap),
        Expanded(child: _tile(indexes[i])),
      ],
    ];
  }

  Widget _single(ChatMessageMedia item) {
    final url = _displayUrl(item);
    if (url == null || url.isEmpty) {
      return _tappable(0, _placeholder(item));
    }
    return AspectRatio(
      aspectRatio:
          chatMediaIsVideo(item.mediaType) ? _heroRatio : _aspectRatio(item),
      child: _tappable(0, _imageStack(url, item, showsCount: false)),
    );
  }

  Widget _tile(int index) {
    final item = media[index];
    final hiddenCount = media.length - maxVisible;
    final showsHiddenCount = index == maxVisible - 1 && hiddenCount > 0;
    final url = _displayUrl(item);

    if (url == null || url.isEmpty) {
      return _tappable(
        index,
        showsHiddenCount
            ? Stack(
              fit: StackFit.expand,
              children: [_placeholder(item), _hiddenCountScrim(hiddenCount)],
            )
            : _placeholder(item),
      );
    }

    return _tappable(
      index,
      _imageStack(
        url,
        item,
        showsCount: showsHiddenCount,
        hiddenCount: hiddenCount,
      ),
    );
  }

  Widget _tappable(int index, Widget child) {
    final clipped = ClipRRect(borderRadius: radius, child: child);
    final onTap = onTapMedia;
    if (onTap == null) return clipped;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: clipped,
    );
  }

  Widget _imageStack(
    String url,
    ChatMessageMedia item, {
    required bool showsCount,
    int hiddenCount = 0,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImageWidget(
          key: networkImageKey(url),
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: const ChatMediaSkeleton(),
          errorWidget: _placeholder(item, withChrome: false),
        ),
        if (chatMediaIsVideo(item.mediaType)) ..._videoChrome(item, showsCount),
        if (showsCount) _hiddenCountScrim(hiddenCount),
      ],
    );
  }

  Widget _hiddenCountScrim(int hiddenCount) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Text(
          '+$hiddenCount',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Play button and, when known, the `0:42` badge over a video poster.
  List<Widget> _videoChrome(ChatMessageMedia item, bool showsCount) {
    final ms = item.durationMs;
    return [
      const ChatVideoPlayBadge(),
      if (ms != null && ms > 0 && !showsCount)
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

  double _aspectRatio(ChatMessageMedia item) {
    final w = item.width;
    final h = item.height;
    if (w != null && h != null && w > 0 && h > 0) {
      final ratio = w / h;
      return ratio.clamp(0.55, 1.8);
    }
    return 4 / 3;
  }

  String? _displayUrl(ChatMessageMedia item) {
    final thumb = item.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) return thumb;
    return item.url;
  }
}
