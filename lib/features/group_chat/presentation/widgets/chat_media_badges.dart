import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_media_limits.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 48px dim circle with a play glyph, centred on a video poster.
class ChatVideoPlayBadge extends StatelessWidget {
  const ChatVideoPlayBadge({super.key, this.icon = AppAssets.play});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

/// `0:42` on a dark rounded chip, bottom-left of a video poster.
class ChatDurationBadge extends StatelessWidget {
  const ChatDurationBadge({super.key, required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatChatDuration(duration),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shimmering block that stands in for a photo or video poster until it has
/// loaded, in the app's skeleton colours (see `SkeletonizerConfigData` in the
/// theme). Fills whatever box it is given.
class ChatMediaSkeleton extends StatelessWidget {
  const ChatMediaSkeleton({
    super.key,
    this.borderRadius = BorderRadius.zero,
    this.onDark = false,
  });

  final BorderRadius borderRadius;

  /// On the black viewer, use the dark theme's shimmer whatever the theme.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      effect:
          onDark
              ? const ShimmerEffect(
                baseColor: Color(0xFF2A2A2A),
                highlightColor: Color(0xFF3A3A3A),
              )
              : null,
      child: SizedBox.expand(
        child: Bone(
          width: double.infinity,
          height: double.infinity,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
