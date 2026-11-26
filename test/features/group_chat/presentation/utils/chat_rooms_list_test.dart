import 'package:flutter_pecha/features/group_chat/data/models/chat_message_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_room_dto.dart';
import 'package:flutter_pecha/features/group_chat/presentation/utils/chat_rooms_list.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessageDTO _message({
  String id = 'm1',
  String body = 'hello',
  String createdAt = '2026-09-01T10:00:00Z',
  String? deletedAt,
  String? senderName,
}) {
  return ChatMessageDTO(
    id: id,
    roomId: 'r1',
    senderId: 'u1',
    senderEmail: 'u1@example.com',
    senderName: senderName,
    body: body,
    createdAt: createdAt,
    deletedAt: deletedAt,
  );
}

ChatRoomDTO _room({
  required String id,
  String? groupId = 'g1',
  String? eventId,
  String? otherUserId,
  String updatedAt = '2026-09-01T10:00:00Z',
  int unreadCount = 0,
  int unreadPrayer = 0,
  ChatMessageDTO? lastMessage,
}) {
  return ChatRoomDTO(
    id: id,
    createdBy: 'u9',
    groupId: groupId,
    eventId: eventId,
    kind: 'group',
    name: 'Room $id',
    memberCount: 3,
    updatedAt: updatedAt,
    unreadChat: unreadCount,
    unreadPrayer: unreadPrayer,
    lastMessage: lastMessage,
    otherUserId: otherUserId,
  );
}

ChatRoomDTO _direct({required String id, int unreadCount = 0}) =>
    _room(id: id, groupId: null, otherUserId: 'team', unreadCount: unreadCount);

void main() {
  group('isDirectChatRoom', () {
    test('is a room with no group or event that names the other person', () {
      expect(isDirectChatRoom(_direct(id: 'd')), isTrue);
    });

    test('a group or event room is not direct', () {
      expect(isDirectChatRoom(_room(id: 'g', otherUserId: 'u2')), isFalse);
      expect(
        isDirectChatRoom(
          _room(id: 'e', groupId: null, eventId: 'ev1', otherUserId: 'u2'),
        ),
        isFalse,
      );
    });

    test('a room without the other person cannot be replied to', () {
      expect(isDirectChatRoom(_room(id: 'x', groupId: null)), isFalse);
      expect(
        isDirectChatRoom(_room(id: 'x', groupId: null, otherUserId: '')),
        isFalse,
      );
    });
  });

  group('chatListRooms', () {
    test('keeps group and direct rooms, drops event rooms', () {
      final rooms = [
        _room(id: 'a'),
        _room(id: 'b', groupId: null),
        _room(id: 'c', groupId: ''),
        _room(id: 'e', groupId: null, eventId: 'ev1'),
        _direct(id: 'd'),
      ];

      expect(chatListRooms(rooms).map((r) => r.id), ['a', 'd']);
    });

    test('drops a room with no id, which cannot be opened', () {
      expect(chatListRooms([_room(id: '')]), isEmpty);
      expect(chatListRooms([_direct(id: '')]), isEmpty);
    });

    test('orders direct and group rooms together by recency', () {
      final rooms = [
        _room(id: 'group', updatedAt: '2026-09-01T10:00:00Z'),
        _room(
          id: 'team',
          groupId: null,
          otherUserId: 'team',
          updatedAt: '2026-09-02T10:00:00Z',
        ),
      ];

      expect(chatListRooms(rooms).map((r) => r.id), ['team', 'group']);
    });

    test('orders most recently active first', () {
      final rooms = [
        _room(id: 'old', updatedAt: '2026-08-01T10:00:00Z'),
        _room(id: 'new', updatedAt: '2026-09-03T10:00:00Z'),
        _room(id: 'mid', updatedAt: '2026-09-01T10:00:00Z'),
      ];

      expect(chatListRooms(rooms).map((r) => r.id), ['new', 'mid', 'old']);
    });

    test('a newer last message outranks a stale updated_at', () {
      final rooms = [
        _room(id: 'quiet', updatedAt: '2026-09-02T10:00:00Z'),
        // The room record was touched long ago, but someone just posted.
        _room(
          id: 'busy',
          updatedAt: '2026-08-01T10:00:00Z',
          lastMessage: _message(createdAt: '2026-09-03T10:00:00Z'),
        ),
      ];

      expect(chatListRooms(rooms).map((r) => r.id), ['busy', 'quiet']);
    });

    test('ties break stably rather than shuffling between refreshes', () {
      final rooms = [_room(id: 'b'), _room(id: 'a')];

      expect(chatListRooms(rooms).map((r) => r.id), ['a', 'b']);
      expect(chatListRooms(rooms.reversed.toList()).map((r) => r.id), [
        'a',
        'b',
      ]);
    });
  });

  group('hasUnreadChatRooms', () {
    test('is true when any group room is unread', () {
      expect(
        hasUnreadChatRooms([_room(id: 'a'), _room(id: 'b', unreadCount: 2)]),
        isTrue,
      );
    });

    test('counts an unread direct room, such as a reply from the Team', () {
      expect(hasUnreadChatRooms([_direct(id: 'd', unreadCount: 1)]), isTrue);
    });

    test('ignores unread event rooms, which are not in the list', () {
      expect(
        hasUnreadChatRooms([
          _room(id: 'e', groupId: null, eventId: 'ev1', unreadCount: 5),
        ]),
        isFalse,
      );
    });

    test('is false when everything is read', () {
      expect(hasUnreadChatRooms([_room(id: 'a')]), isFalse);
    });
  });

  group('chatRoomIsUnread', () {
    test('counts the chat only: the Chats list opens the chat', () {
      expect(chatRoomIsUnread(_room(id: 'a', unreadCount: 1)), isTrue);
      expect(chatRoomIsUnread(_room(id: 'a', unreadPrayer: 3)), isFalse);
    });
  });

  group('spaceUnreadOf', () {
    test('says whether chat and prayer requests are unread', () {
      expect(
        spaceUnreadOf(_room(id: 'a', unreadCount: 4, unreadPrayer: 2)),
        const SpaceUnread(chat: true, prayer: true),
      );
      expect(spaceUnreadOf(_room(id: 'a')).any, isFalse);
    });

    test('prayer requests alone are unread too', () {
      final unread = spaceUnreadOf(_room(id: 'a', unreadPrayer: 1));
      expect(unread, const SpaceUnread(prayer: true));
      expect(unread.any, isTrue);
    });
  });

  group('unreadSpaces', () {
    test('maps each unread space room to its group, and nothing else', () {
      expect(
        unreadSpaces([
          _room(id: 'r1', groupId: 'a', unreadCount: 2),
          _room(id: 'r2', groupId: 'b'),
          _room(id: 'r5', groupId: 'c', unreadPrayer: 1),
          _direct(id: 'r3', unreadCount: 5),
          _room(id: 'r4', groupId: null, eventId: 'ev1', unreadCount: 1),
        ]),
        {
          'a': const SpaceUnread(chat: true),
          'c': const SpaceUnread(prayer: true),
        },
      );
    });
  });

  group('roomsWithRoomRead', () {
    List<ChatRoomDTO> rooms() => [
      _room(id: 'a', unreadCount: 2),
      _room(id: 'b', unreadCount: 3, unreadPrayer: 1),
    ];

    test('with no type, zeroes only that room and keeps the order', () {
      final read = roomsWithRoomRead(rooms(), 'b');

      expect([for (final room in read) room.id], ['a', 'b']);
      expect([for (final room in read) room.unreadCount], [2, 0]);
      expect(read[1], _room(id: 'b'));
    });

    test('TEXT clears the chat and leaves prayer requests unread', () {
      final read = roomsWithRoomRead(
        rooms(),
        'b',
        messageType: ChatMessageDTO.typeText,
      );

      expect(read[1].unreadChat, 0);
      expect(read[1].unreadPrayer, 1);
    });

    test('PRAYER clears prayer requests and leaves the chat unread', () {
      final read = roomsWithRoomRead(
        rooms(),
        'b',
        messageType: ChatMessageDTO.typePrayer,
      );

      expect(read[1].unreadChat, 3);
      expect(read[1].unreadPrayer, 0);
    });

    test('returns the same list when there is nothing to clear', () {
      final list = rooms();

      expect(roomsWithRoomRead(list, 'missing'), same(list));
      expect(
        roomsWithRoomRead(list, 'a', messageType: ChatMessageDTO.typePrayer),
        same(list),
      );
    });
  });

  group('isChatPushPayload', () {
    test('reads session_type', () {
      expect(isChatPushPayload({'session_type': 'CHAT'}), isTrue);
      expect(isChatPushPayload({'session_type': 'GROUP_POST'}), isFalse);
    });

    test('falls back to type, and is case and space insensitive', () {
      // Matching how resolvePushTap reads the same map, so the two cannot
      // disagree about what a chat push is.
      expect(isChatPushPayload({'type': ' chat '}), isTrue);
      expect(isChatPushPayload({'session_type': '', 'type': 'CHAT'}), isTrue);
    });

    test('an empty payload is not a chat push', () {
      expect(isChatPushPayload(const {}), isFalse);
    });
  });

  group('isPrayerPushPayload', () {
    const chat = {'session_type': 'CHAT'};

    test('prayer request and prayer received pushes are prayer pushes', () {
      expect(
        isPrayerPushPayload({...chat, 'notification_type': 'PRAYER_REQUEST'}),
        isTrue,
      );
      expect(
        isPrayerPushPayload({...chat, 'notification_type': 'prayer_received'}),
        isTrue,
      );
    });

    test('a chat message or untyped chat push is not', () {
      expect(
        isPrayerPushPayload({...chat, 'notification_type': 'CHAT_MESSAGE'}),
        isFalse,
      );
      expect(isPrayerPushPayload(chat), isFalse);
    });

    test('a push that is not a chat push is not', () {
      expect(
        isPrayerPushPayload({
          'session_type': 'GROUP_POST',
          'notification_type': 'PRAYER_REQUEST',
        }),
        isFalse,
      );
    });
  });

  group('chatPushTargets', () {
    const chat = {'session_type': 'CHAT'};

    test('matches the room by source_id', () {
      // The backend sets source_id to the room id, not the group id.
      expect(
        chatPushTargets({...chat, 'source_id': 'r1'}, roomId: 'r1'),
        isTrue,
      );
      expect(
        chatPushTargets({...chat, 'source_id': 'other'}, roomId: 'r1'),
        isFalse,
      );
    });

    test('matches the group when the room is not yet known', () {
      // A thread opened by group can receive its first push before the room
      // id has been resolved.
      expect(
        chatPushTargets(
          {...chat, 'group_id': 'g1'},
          roomId: null,
          groupId: 'g1',
        ),
        isTrue,
      );
    });

    test('ignores a chat push for somewhere else', () {
      expect(
        chatPushTargets(
          {...chat, 'source_id': 'r9', 'group_id': 'g9'},
          roomId: 'r1',
          groupId: 'g1',
        ),
        isFalse,
      );
    });

    test('ignores a push that is not a chat message at all', () {
      expect(
        chatPushTargets({
          'session_type': 'GROUP_POST',
          'source_id': 'r1',
        }, roomId: 'r1'),
        isFalse,
      );
    });

    test('empty ids never match', () {
      expect(
        chatPushTargets({...chat, 'source_id': ''}, roomId: '', groupId: ''),
        isFalse,
      );
    });
  });

  group('chatRoomPreviewBody', () {
    test('is null for a room nobody has written in', () {
      expect(
        chatRoomPreviewBody(_room(id: 'a'), deletedLabel: 'deleted'),
        isNull,
      );
    });

    test('flattens newlines so the preview stays on two tidy lines', () {
      final room = _room(
        id: 'a',
        lastMessage: _message(body: 'first\n\n  second\nthird'),
      );

      expect(
        chatRoomPreviewBody(room, deletedLabel: 'deleted'),
        'first second third',
      );
    });

    test('a deleted message never shows its body', () {
      // The body still arrives on the wire; showing it would contradict the
      // tombstone one tap away.
      final room = _room(
        id: 'a',
        lastMessage: _message(
          body: 'the original text',
          deletedAt: '2026-09-03T11:00:00Z',
        ),
      );

      expect(chatRoomPreviewBody(room, deletedLabel: 'deleted'), 'deleted');
    });

    test('is null when the body is only whitespace', () {
      final room = _room(id: 'a', lastMessage: _message(body: '   \n  '));

      expect(chatRoomPreviewBody(room, deletedLabel: 'deleted'), isNull);
    });

    test('a Help & contact message previews what the user wrote', () {
      final room = _room(
        id: 'd',
        groupId: null,
        otherUserId: 'team',
        lastMessage: _message(
          body:
              'Sent from Help & contact · Help or collaborate\n\n'
              'I translate dharma texts into Nepali',
        ),
      );

      expect(
        chatRoomPreviewBody(room, deletedLabel: 'deleted'),
        'I translate dharma texts into Nepali',
      );
    });
  });
}
