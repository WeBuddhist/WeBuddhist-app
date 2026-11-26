import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_space_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/screens/your_spaces_screen.dart';
import 'package:flutter_pecha/features/connect/presentation/utils/connect_analytics.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_landing_view.dart';
import 'package:flutter_pecha/features/connect/presentation/widgets/connect_unread_dot.dart';
import 'package:flutter_pecha/features/group_profile/presentation/screens/group_profile_screen.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_profile_skeleton.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Connect tab: the landing page for guests and members with no spaces,
/// otherwise the page of the space last opened, with ☰ to switch spaces.
class ConnectTabScreen extends ConsumerStatefulWidget {
  const ConnectTabScreen({super.key});

  @override
  ConsumerState<ConnectTabScreen> createState() => _ConnectTabScreenState();
}

class _ConnectTabScreenState extends ConsumerState<ConnectTabScreen> {
  String? _trackedView;

  /// Once per settled view, with the joined count it was decided on.
  void _trackView(String view, int spaceCount) {
    if (view == _trackedView) return;
    _trackedView = view;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(connectAnalyticsProvider)
          .tabViewed(subTab: view, followedGroupCount: spaceCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMember = ref.watch(
      authProvider.select((auth) => auth.isLoggedIn && !auth.isGuest),
    );
    if (!isMember) {
      _trackView('landing', 0);
      return const ConnectLandingView();
    }

    final joined = ref.watch(joinedSpacesProvider);
    final lastSpace = ref.watch(connectLastSpaceProvider);
    final opened = ref.watch(connectOpenedSpacesProvider);
    if (joined.isLoading ||
        (joined.spaces.isNotEmpty && (!lastSpace.loaded || !opened.loaded))) {
      return const GroupProfileSkeleton();
    }

    final space = resolveConnectSpace(
      joined: joined.spaces,
      rememberedId: lastSpace.spaceId,
    );
    if (space == null) {
      _trackView('landing', 0);
      return const ConnectLandingView();
    }

    _trackView('space', joined.spaces.length);
    return GroupProfileScreen(
      key: ValueKey(space.id),
      groupId: space.id,
      leading: _SpacesMenuButton(currentSpaceId: space.id),
      analyticsSource: GroupViewSource.connectTab,
      startCollapsed: _landsOnFeed(space.id, opened),
    );
  }

  /// The space the landing decision below was made for.
  String? _landingSpaceId;
  bool _landingOnFeed = false;

  /// Landing rule: the first visit to a space opens on its info, every later
  /// visit on its feed. Decided once per visit, then the space is recorded
  /// as opened, so recording it does not flip the visit already on screen.
  bool _landsOnFeed(String spaceId, ConnectOpenedSpaces opened) {
    if (spaceId == _landingSpaceId) return _landingOnFeed;
    _landingSpaceId = spaceId;
    _landingOnFeed = opened.ids.contains(spaceId);
    if (!_landingOnFeed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(connectOpenedSpacesProvider.notifier).markOpened(spaceId);
      });
    }
    return _landingOnFeed;
  }
}

/// ☰ that opens "Your spaces", dotted when another space has unread
/// messages. The space on screen dots its own chat or prayer button instead.
class _SpacesMenuButton extends ConsumerWidget {
  const _SpacesMenuButton({required this.currentSpaceId});

  final String currentSpaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUnread = ref.watch(
      unreadSpacesProvider.select(
        (spaces) => spaces.keys.any((id) => id != currentSpaceId),
      ),
    );

    return IconButton(
      onPressed:
          () => YourSpacesScreen.show(context, currentSpaceId: currentSpaceId),
      tooltip: context.l10n.connect_your_spaces,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(AppAssets.list),
          if (otherUnread)
            const Positioned(top: -1, right: -1, child: ConnectUnreadDot()),
        ],
      ),
    );
  }
}
