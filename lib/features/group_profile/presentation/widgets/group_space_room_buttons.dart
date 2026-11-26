import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/router/app_routes.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_space_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_unread_dot.dart';
import 'package:flutter_pecha/features/group_chat/domain/prayer_room_scope.dart';
import 'package:flutter_pecha/features/group_chat/presentation/providers/chat_rooms_providers.dart';
import 'package:flutter_pecha/features/group_chat/presentation/widgets/prayer_requests_sheet.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_member_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Prayer requests and chat for a space: on the space page's app bar, so
/// they stay reachable with the header scrolled away, and on the group
/// drawer's handle row, which has no app bar. Shown to the same signed-in,
/// confirmed members as the ⋮ beside Invite; otherwise an empty slot
/// [hiddenWidth] wide (48 keeps the app bar's fading title centred).
///
/// Each carries the Connect unread dot for what is unread in this space, so
/// the dot that led here from ☰ ends on the button that shows it.
class GroupSpaceRoomButtons extends ConsumerWidget {
  final GroupProfile profile;
  final double hiddenWidth;

  const GroupSpaceRoomButtons({
    super.key,
    required this.profile,
    this.hiddenWidth = 48,
  });

  /// Opens the space's chat. Coming back refetches the rooms the dots read,
  /// as the Chats screen does: the chat clears its own room as it marks it
  /// read, but messages may have landed in other spaces meanwhile.
  Future<void> _openChat(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    await context.push(AppRoutes.groupChatPath(profile.id));
    if (container.exists(chatRoomsProvider)) {
      unawaited(container.read(chatRoomsProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followKey = GroupFollowKey(
      groupId: profile.id,
      groupType: profile.groupType,
    );
    final auth = ref.watch(authProvider);
    final shows = showsGroupMemberMenu(
      followState: ref.watch(groupFollowProvider(followKey)),
      signedIn: auth.isLoggedIn && !auth.isGuest,
    );
    if (!shows) return SizedBox(width: hiddenWidth, height: 48);

    final unread = ref.watch(
      unreadSpacesProvider.select((spaces) => spaces[profile.id]),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DottedIconButton(
          icon: AppAssets.handsPraying,
          tooltip: context.l10n.event_prayer_requests,
          hasUnread: unread?.prayer ?? false,
          onPressed: () => unawaited(
            PrayerRequestsSheet.show(
              context,
              scope: PrayerRoomScope.group(profile.id),
              source: 'group_page',
            ),
          ),
        ),
        _DottedIconButton(
          icon: AppAssets.chatCircleDots,
          tooltip: context.l10n.group_chat_open,
          hasUnread: unread?.chat ?? false,
          onPressed: () => _openChat(context),
        ),
      ],
    );
  }
}

/// Icon button with the Connect unread dot on its top-right corner,
/// placed like the dot on ☰.
class _DottedIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool hasUnread;
  final VoidCallback onPressed;

  const _DottedIconButton({
    required this.icon,
    required this.tooltip,
    required this.hasUnread,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (hasUnread)
            const Positioned(top: -1, right: -1, child: ConnectUnreadDot()),
        ],
      ),
    );
  }
}
