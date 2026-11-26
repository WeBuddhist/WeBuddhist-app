import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_visible_name.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_room_mantra_dto.dart';

class ChatRoomDTO extends Equatable {
  final String id;
  final String createdBy;
  final String? groupId;

  /// Set on an `EVENT` room, in place of [groupId].
  final String? eventId;
  final String? senderId;
  final String? receiverId;
  final String kind;
  final String name;
  final String? imgUrl;
  final int memberCount;
  final String updatedAt;
  final ChatMessageDTO? lastMessage;

  /// Unread chat messages (`TEXT`), the viewer's own included until the chat
  /// is marked read.
  final int unreadChat;

  /// Unread prayer requests (`PRAYER`), counted the same way.
  final int unreadPrayer;
  final String? otherUserId;
  final String? otherUserEmail;
  final String? otherUserName;

  /// The viewer's direct chat with the WeBuddhist Team, which the backend
  /// starts when they send a message from Help & contact. Not in the spec
  /// yet; absent reads as false, so the room just shows as a plain chat.
  final bool isOfficial;

  /// What an event or space room floats up on each prayer; null falls back
  /// to the app's built-in mantra.
  final ChatRoomMantraDTO? mantra;

  const ChatRoomDTO({
    required this.id,
    required this.createdBy,
    this.groupId,
    this.eventId,
    this.senderId,
    this.receiverId,
    required this.kind,
    required this.name,
    this.imgUrl,
    this.memberCount = 0,
    required this.updatedAt,
    this.lastMessage,
    this.unreadChat = 0,
    this.unreadPrayer = 0,
    this.otherUserId,
    this.otherUserEmail,
    this.otherUserName,
    this.isOfficial = false,
    this.mantra,
  });

  /// Reads v2 (`unread: {"TEXT": n, "PRAYER": n}`, `space_id`) and v1
  /// (`unread_count`, `group_id`) alike: rooms stored on the device before
  /// the move to v2 still load. v1's one count stands for the chat.
  factory ChatRoomDTO.fromJson(Map<String, dynamic> json) {
    final lastMessageJson = json['last_message'];
    final mantraJson = json['mantra'];
    final unread = json['unread'];
    final byType = unread is Map ? unread : null;
    return ChatRoomDTO(
      id: json['id'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? '',
      groupId: json['space_id'] as String? ?? json['group_id'] as String?,
      eventId: json['event_id'] as String?,
      senderId: json['sender_id'] as String?,
      receiverId: json['receiver_id'] as String?,
      kind: json['kind'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imgUrl: json['img_url'] as String?,
      memberCount: _readInt(json['member_count']),
      updatedAt: json['updated_at'] as String? ?? '',
      lastMessage:
          lastMessageJson is Map<String, dynamic>
              ? ChatMessageDTO.fromJson(lastMessageJson)
              : null,
      unreadChat:
          byType != null
              ? _readInt(byType[ChatMessageDTO.typeText])
              : _readInt(json['unread_count']),
      unreadPrayer:
          byType != null ? _readInt(byType[ChatMessageDTO.typePrayer]) : 0,
      otherUserId: json['other_user_id']?.toString(),
      otherUserEmail: json['other_user_email'] as String?,
      otherUserName: chatVisibleName(
        json['other_user_display_name'],
        json['other_user_name'],
      ),
      isOfficial: json['is_official'] == true,
      mantra:
          mantraJson is Map<String, dynamic>
              ? ChatRoomMantraDTO.fromJson(mantraJson)
              : null,
    );
  }

  /// Everything unread, chat and prayer requests together.
  int get unreadCount => unreadChat + unreadPrayer;

  /// This room with the given unread counts replaced, the rest kept.
  ChatRoomDTO copyWithUnread({int? chat, int? prayer}) {
    return ChatRoomDTO(
      id: id,
      createdBy: createdBy,
      groupId: groupId,
      eventId: eventId,
      senderId: senderId,
      receiverId: receiverId,
      kind: kind,
      name: name,
      imgUrl: imgUrl,
      memberCount: memberCount,
      updatedAt: updatedAt,
      lastMessage: lastMessage,
      unreadChat: chat ?? unreadChat,
      unreadPrayer: prayer ?? unreadPrayer,
      otherUserId: otherUserId,
      otherUserEmail: otherUserEmail,
      otherUserName: otherUserName,
      isOfficial: isOfficial,
      mantra: mantra,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_by': createdBy,
      if (groupId != null) 'group_id': groupId,
      if (eventId != null) 'event_id': eventId,
      if (senderId != null) 'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      'kind': kind,
      'name': name,
      if (imgUrl != null) 'img_url': imgUrl,
      'member_count': memberCount,
      'updated_at': updatedAt,
      if (lastMessage != null) 'last_message': lastMessage!.toJson(),
      'unread': {
        ChatMessageDTO.typeText: unreadChat,
        ChatMessageDTO.typePrayer: unreadPrayer,
      },
      if (otherUserId != null) 'other_user_id': otherUserId,
      if (otherUserEmail != null) 'other_user_email': otherUserEmail,
      if (otherUserName != null) 'other_user_name': otherUserName,
      if (isOfficial) 'is_official': true,
      if (mantra != null) 'mantra': mantra!.toJson(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    createdBy,
    groupId,
    eventId,
    senderId,
    receiverId,
    kind,
    name,
    imgUrl,
    memberCount,
    updatedAt,
    lastMessage,
    unreadChat,
    unreadPrayer,
    otherUserId,
    otherUserEmail,
    otherUserName,
    isOfficial,
    mantra,
  ];
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
