import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_message_media_preview.dart';
import 'package:flutter_pecha/core/utils/network_image_utils.dart';

/// In-thread grid for chat message photos and video posters.
class ChatMessageMediaBubble extends StatelessWidget {
  const ChatMessageMediaBubble({
    super.key,
    required this.media,
    required this.isDark,
  });

  final List<ChatMessageMedia> media;
  final bool isDark;

  static const maxVisible = 4;
  static const gap = 2.0;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final grid = switch (media.length) {
      1 => _single(media.first),
      2 => AspectRatio(aspectRatio: 2, child: Row(children: _row([0, 1]))),
      3 => AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: [
            Expanded(child: Row(children: _row([0, 1]))),
            const SizedBox(height: gap),
            Expanded(child: _tile(2)),
          ],
        ),
      ),
      _ => AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: [
            Expanded(child: Row(children: _row([0, 1]))),
            const SizedBox(height: gap),
            Expanded(child: Row(children: _row([2, 3]))),
          ],
        ),
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: grid),
    );
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
      return _placeholder(item);
    }
    return AspectRatio(
      aspectRatio: _aspectRatio(item),
      child: _imageStack(url, item, showsCount: false),
    );
  }

  Widget _tile(int index) {
    final item = media[index];
    final hiddenCount = media.length - maxVisible;
    final showsHiddenCount = index == maxVisible - 1 && hiddenCount > 0;
    final url = _displayUrl(item);

    if (url == null || url.isEmpty) {
      return _placeholder(item);
    }

    return _imageStack(
      url,
      item,
      showsCount: showsHiddenCount,
      hiddenCount: hiddenCount,
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
          errorWidget: _placeholder(item),
        ),
        if (chatMediaIsVideo(item.mediaType)) _videoBadge(),
        if (showsCount)
          ColoredBox(
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
          ),
      ],
    );
  }

  Widget _videoBadge() {
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(AppAssets.play, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _placeholder(ChatMessageMedia item) {
    return ColoredBox(
      color: isDark ? AppColors.grey800 : AppColors.grey100,
      child: Center(
        child: Icon(
          chatMediaIsVideo(item.mediaType) ? AppAssets.play : AppAssets.image,
          color: isDark ? AppColors.grey500 : AppColors.grey600,
          size: 28,
        ),
      ),
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