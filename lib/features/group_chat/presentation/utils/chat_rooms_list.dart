import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/features/feedback/domain/help_context_line.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_room_dto.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_message_time.dart';

/// Whether [room] is a direct chat between two people.
///
/// Decided by what the room carries rather than `kind`, for the same reason
/// [chatListRooms] uses `group_id`: the spec types `kind` as a bare string.
/// A direct room has no group or event and names the other person, and that
/// person's id is what a reply is sent to.
bool isDirectChatRoom(ChatRoomDTO room) {
  return (room.groupId ?? '').isEmpty &&
      (room.eventId ?? '').isEmpty &&
      (room.otherUserId ?? '').isNotEmpty;
}

/// The name to show for [room]. A direct room is named after the other
/// person when the server says who that is.
String chatRoomTitle(ChatRoomDTO room) {
  if (isDirectChatRoom(room)) {
    final other = room.otherUserName?.trim() ?? '';
    if (other.isNotEmpty) return other;
  }
  return room.name;
}

/// The rooms the Chats list shows among [rooms], most recently active first:
/// group chats and direct chats.
///
/// `/chat/rooms` also returns event rooms, which hold an event's prayer
/// requests and open from the event, so they are left out. Group membership is
/// decided by `group_id` rather than `kind`: the spec types `kind` as a bare
/// string with no enum, while `resolve_group_chat_room` already identifies a
/// group room by its `group_id`. One rule, already proven.
///
/// Direct chats are in because the app cannot start one: the only ones a
/// member has are the WeBuddhist Team chats the backend opens from Help &
/// contact, and the Team account answers from this same list.
///
/// Sorted here rather than trusted from the server: the endpoint documents no
/// ordering, and "most recent first" is the requirement.
List<ChatRoomDTO> chatListRooms(List<ChatRoomDTO> rooms) {
  final listed =
      rooms
          .where(
            (room) =>
                room.id.isNotEmpty &&
                ((room.groupId ?? '').isNotEmpty || isDirectChatRoom(room)),
          )
          .toList();

  listed.sort((a, b) {
    final byRecency = chatRoomSortKey(b).compareTo(chatRoomSortKey(a));
    if (byRecency != 0) return byRecency;
    // A stable tiebreak, so rooms with identical timestamps do not swap
    // places between refreshes.
    return a.id.compareTo(b.id);
  });
  return listed;
}

/// When a room last changed, for ordering.
///
/// The last message wins over `updated_at` when it is newer: `updated_at` also
/// moves for edits to the room itself, and an ordering that disagrees with the
/// visible preview line reads as a bug.
DateTime chatRoomSortKey(ChatRoomDTO room) {
  final updated = parseChatTimestamp(room.updatedAt);
  final message = room.lastMessage;
  if (message == null) return updated;

  final sent = message.createdAtLocal;
  return sent.isAfter(updated) ? sent : updated;
}

/// Whether the room has unread chat — the Chats list's badge and dot.
/// Prayer requests are left out: that list opens the chat, which marks only
/// the chat read, so a prayer count there would never clear.
bool chatRoomIsUnread(ChatRoomDTO room) => room.unreadChat > 0;

/// Whether any listed room has unread chat.
bool hasUnreadChatRooms(List<ChatRoomDTO> rooms) {
  return chatListRooms(rooms).any(chatRoomIsUnread);
}

/// What is unread in a space's room, which holds both its chat and its
/// prayer requests. Each shows as a dot on its own button, never a count.
class SpaceUnread extends Equatable {
  const SpaceUnread({this.chat = false, this.prayer = false});

  /// Whether any chat message is unread.
  final bool chat;

  /// Whether any prayer request is unread.
  final bool prayer;

  bool get any => chat || prayer;

  @override
  List<Object?> get props => [chat, prayer];
}

SpaceUnread spaceUnreadOf(ChatRoomDTO room) {
  return SpaceUnread(chat: room.unreadChat > 0, prayer: room.unreadPrayer > 0);
}

/// Unread spaces among [rooms], by group id. Only rooms the chats list has
/// loaded count, so a space past that page shows no dot.
Map<String, SpaceUnread> unreadSpaces(List<ChatRoomDTO> rooms) {
  final spaces = <String, SpaceUnread>{};
  for (final room in chatListRooms(rooms)) {
    final groupId = room.groupId ?? '';
    final unread = spaceUnreadOf(room);
    if (groupId.isNotEmpty && unread.any) spaces[groupId] = unread;
  }
  return spaces;
}

/// [rooms] with [roomId]'s [messageType] read (`TEXT` or `PRAYER`), or every
/// type when null, for when the server has just been told so. Returns
/// [rooms] itself when nothing changes.
List<ChatRoomDTO> roomsWithRoomRead(
  List<ChatRoomDTO> rooms,
  String roomId, {
  String? messageType,
}) {
  final chat = messageType == null || messageType == ChatMessageDTO.typeText;
  final prayer =
      messageType == null || messageType == ChatMessageDTO.typePrayer;
  bool clears(ChatRoomDTO room) =>
      room.id == roomId &&
      ((chat && room.unreadChat > 0) || (prayer && room.unreadPrayer > 0));

  if (!rooms.any(clears)) return rooms;
  return [
    for (final room in rooms)
      clears(room)
          ? room.copyWithUnread(
            chat: chat ? 0 : null,
            prayer: prayer ? 0 : null,
          )
          : room,
  ];
}

/// Whether an FCM payload is a chat message.
///
/// Mirrors how `resolvePushTap` reads the same map — `session_type` first,
/// falling back to `type`, upper-cased — so the two cannot disagree about what
/// a chat push is.
bool isChatPushPayload(Map<String, dynamic> data) {
  final session = (data['session_type'] as String?)?.trim();
  final raw =
      session != null && session.isNotEmpty
          ? session
          : (data['type'] as String?)?.trim() ?? '';
  return raw.toUpperCase() == 'CHAT';
}

/// The room a chat push names. The backend sets `source_id` to the room id.
String chatPushRoomId(Map<String, dynamic> data) =>
    (data['source_id'] as String?)?.trim() ?? '';

/// The group a chat push names.
String chatPushGroupId(Map<String, dynamic> data) =>
    (data['group_id'] as String?)?.trim() ?? '';

/// Whether a chat push is about a prayer request rather than a chat message.
/// A space's room carries both, but group chat shows only chat messages.
bool isPrayerPushPayload(Map<String, dynamic> data) {
  if (!isChatPushPayload(data)) return false;
  final type =
      (data['notification_type'] as String?)?.trim().toUpperCase() ?? '';
  return type == 'PRAYER_REQUEST' || type == 'PRAYER_RECEIVED';
}

/// Whether a chat push is about the room or group currently on screen.
bool chatPushTargets(
  Map<String, dynamic> data, {
  String? roomId,
  String? groupId,
}) {
  if (!isChatPushPayload(data)) return false;

  final room = (roomId ?? '').trim();
  if (room.isNotEmpty && chatPushRoomId(data) == room) return true;

  final group = (groupId ?? '').trim();
  return group.isNotEmpty && chatPushGroupId(data) == group;
}

/// The preview line's message text, with newlines flattened so a multi-line
/// message stays tidy on two lines.
///
/// Returns null when the room has never been written in, and [deletedLabel]
/// when the last message has been deleted — a deleted message still arrives
/// carrying its body, and showing that here would contradict the tombstone one
/// tap away. A Help & contact message previews what the user wrote, not the
/// "Sent from Help & contact" line above it.
String? chatRoomPreviewBody(ChatRoomDTO room, {required String deletedLabel}) {
  final message = room.lastMessage;
  if (message == null) return null;
  if (message.deletedAt != null) return deletedLabel;

  final text = parseHelpContext(message.body)?.body ?? message.body;
  final body = text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
  return body.isEmpty ? null : body;
}
