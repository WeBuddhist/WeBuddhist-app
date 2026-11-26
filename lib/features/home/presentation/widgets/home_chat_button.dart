import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/router/app_routes.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_unread_dot.dart';
import 'package:flutter_pecha/features/group_chat/presentation/providers/chat_rooms_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home header's way into every space chat and DM (`/chats`), with a red
/// dot while any room is unread. Guests get the sign-in drawer instead.
class HomeChatButton extends ConsumerWidget {
  const HomeChatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMember = ref.watch(
      authProvider.select((auth) => auth.isLoggedIn && !auth.isGuest),
    );
    if (!isMember) {
      return HomeChatIconButton(
        hasUnread: false,
        onPressed: () => LoginDrawer.show(context, ref),
      );
    }

    // Keeps the rooms list, and so the dot, current while Home shows it.
    ref.watch(chatRoomsPushRefreshProvider);
    ref.watch(chatRoomsSignalsProvider);
    final hasUnread = ref.watch(
      chatRoomsProvider.select((state) => state.hasUnread),
    );
    return HomeChatIconButton(
      hasUnread: hasUnread,
      onPressed: () => context.push(AppRoutes.chats),
    );
  }
}

/// The chat icon itself, with the unread dot on its top-right.
class HomeChatIconButton extends StatelessWidget {
  const HomeChatIconButton({
    super.key,
    required this.hasUnread,
    required this.onPressed,
  });

  final bool hasUnread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: context.l10n.chats_title,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            AppAssets.chatCircleDots,
            size: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          if (hasUnread)
            const Positioned(top: -1, right: -1, child: ConnectUnreadDot()),
        ],
      ),
    );
  }
}
