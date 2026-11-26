import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';

/// The red dot for unread messages in a space's room, chat or prayer
/// requests (`unreadSpacesProvider`). It shows on ☰ for another space, on
/// that space in "Your spaces", and on the space page's chat or prayer
/// button, so each dot leads to the next one and ends where the messages are.
class ConnectUnreadDot extends StatelessWidget {
  const ConnectUnreadDot({super.key, this.size = 9});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            theme.brightness == Brightness.dark
                ? AppColors.unreadBadgeDark
                : AppColors.unreadBadge,
        shape: BoxShape.circle,
        // Rings the dot in the background colour so it stays legible over
        // an icon.
        border: Border.all(color: theme.scaffoldBackgroundColor),
      ),
    );
  }
}
