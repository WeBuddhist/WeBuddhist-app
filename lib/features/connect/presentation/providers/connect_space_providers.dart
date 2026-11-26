import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/storage/storage_keys.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/connect/presentation/providers/connect_providers.dart';
import 'package:flutter_pecha/features/group_chat/presentation/providers/chat_rooms_providers.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_rooms_list.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The spaces the member has joined, including joins and leaves this session
/// that the my-groups API does not reflect yet.
class JoinedSpaces {
  const JoinedSpaces({required this.spaces, required this.isLoading});

  final List<GroupProfile> spaces;

  /// True only while the first read is out with nothing known yet, so the
  /// Connect tab can wait instead of flashing the landing page at a member.
  /// A failed read is not loading: the landing page shows instead.
  final bool isLoading;
}

final joinedSpacesProvider = Provider<JoinedSpaces>((ref) {
  final myGroupsAsync = ref.watch(myGroupsProvider);
  final spaces = mergeMyGroupsWithPending(
    apiGroups: myGroupsAsync.valueOrNull?.groups ?? const [],
    pendingGroups: ref.watch(pendingJoinedGroupsProvider),
    pendingUnjoinedIds: ref.watch(pendingUnjoinedGroupIdsProvider),
  );
  return JoinedSpaces(
    spaces: spaces,
    isLoading:
        spaces.isEmpty && myGroupsAsync.isLoading && !myGroupsAsync.hasValue,
  );
});

/// Refetches the member's spaces, keeping what is on screen. Also how a
/// failed first read recovers: the landing page it leaves a member on has no
/// other way back to their spaces. Does nothing for guests.
Future<void> refreshJoinedSpaces(
  T Function<T>(ProviderListenable<T> provider) read,
) async {
  final auth = read(authProvider);
  if (!auth.isLoggedIn || auth.isGuest) return;
  await read(
    connectRepositoryProvider,
  ).refreshMyGroups(language: read(contentLanguageProvider));
}

/// The remembered space if it is still joined, otherwise the first joined
/// one; null when the member has joined none.
GroupProfile? resolveConnectSpace({
  required List<GroupProfile> joined,
  required String? rememberedId,
}) {
  if (joined.isEmpty) return null;
  for (final space in joined) {
    if (space.id == rememberedId) return space;
  }
  return joined.first;
}

/// The space the Connect tab last showed, kept across launches.
class ConnectLastSpace {
  const ConnectLastSpace({this.spaceId, this.loaded = false});

  final String? spaceId;

  /// False until the stored id has been read, so the tab does not open one
  /// space and then jump to another.
  final bool loaded;
}

class ConnectLastSpaceNotifier extends StateNotifier<ConnectLastSpace> {
  ConnectLastSpaceNotifier() : super(const ConnectLastSpace()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || state.loaded) return;
    state = ConnectLastSpace(
      spaceId: prefs.getString(StorageKeys.connectLastSpaceId),
      loaded: true,
    );
  }

  Future<void> select(String spaceId) async {
    if (spaceId.isEmpty) return;
    state = ConnectLastSpace(spaceId: spaceId, loaded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.connectLastSpaceId, spaceId);
  }
}

final connectLastSpaceProvider =
    StateNotifierProvider<ConnectLastSpaceNotifier, ConnectLastSpace>(
      (ref) => ConnectLastSpaceNotifier(),
    );

/// The spaces the Connect tab has already opened, kept across launches.
///
/// Drives the landing rule: the first visit to a space opens on its info
/// (header expanded), every later visit opens on its feed with the header
/// scrolled away.
class ConnectOpenedSpaces {
  const ConnectOpenedSpaces({this.ids = const {}, this.loaded = false});

  final Set<String> ids;

  /// False until the stored ids have been read, so a returning visit is not
  /// mistaken for a first one.
  final bool loaded;
}

class ConnectOpenedSpacesNotifier extends StateNotifier<ConnectOpenedSpaces> {
  ConnectOpenedSpacesNotifier() : super(const ConnectOpenedSpaces()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || state.loaded) return;
    state = ConnectOpenedSpaces(
      ids: {
        ...?prefs.getStringList(StorageKeys.connectOpenedSpaceIds),
        // A space marked before the read finished.
        ...state.ids,
      },
      loaded: true,
    );
  }

  Future<void> markOpened(String spaceId) async {
    if (spaceId.isEmpty || state.ids.contains(spaceId)) return;
    final ids = {...state.ids, spaceId};
    state = ConnectOpenedSpaces(ids: ids, loaded: state.loaded);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      StorageKeys.connectOpenedSpaceIds,
      {
        ...?prefs.getStringList(StorageKeys.connectOpenedSpaceIds),
        ...ids,
      }.toList(),
    );
  }
}

final connectOpenedSpacesProvider =
    StateNotifierProvider<ConnectOpenedSpacesNotifier, ConnectOpenedSpaces>(
      (ref) => ConnectOpenedSpacesNotifier(),
    );

/// Spaces with unread messages in their room, by group id, and whether the
/// space page should send the member to its chat or its prayer requests
/// ([unreadSpaces]). Drives every Connect dot: ☰, "Your spaces", and the
/// space page's chat or prayer button. Empty for guests, who never load the
/// rooms.
final unreadSpacesProvider = Provider.autoDispose<Map<String, SpaceUnread>>((
  ref,
) {
  final isMember = ref.watch(
    authProvider.select((auth) => auth.isLoggedIn && !auth.isGuest),
  );
  if (!isMember) return const {};

  // Keep the list current while a dot is on screen.
  ref.watch(chatRoomsPushRefreshProvider);
  ref.watch(chatRoomsSignalsProvider);
  return unreadSpaces(ref.watch(chatRoomsProvider).rooms);
});
