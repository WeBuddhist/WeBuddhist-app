import 'package:flutter_pecha/features/group_chat/data/models/chat_message_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_parent_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _messageJson({
  String? senderName,
  String? senderDisplayName,
  Map<String, dynamic>? parent,
}) => {
  'id': 'm1',
  'room_id': 'r1',
  'sender_id': 'u1',
  'sender_email': 'tenzin@example.com',
  if (senderName != null) 'sender_name': senderName,
  if (senderDisplayName != null) 'sender_display_name': senderDisplayName,
  'body': 'Tashi delek',
  'created_at': '2026-11-19T10:00:00Z',
  if (parent != null) 'parent': parent,
};

void main() {
  group('ChatMessageDTO sender name', () {
    test('prefers sender_display_name over sender_name', () {
      final message = ChatMessageDTO.fromJson(
        _messageJson(senderName: 'Tenzin Dorje', senderDisplayName: ' tenz '),
      );

      expect(message.senderName, 'tenz');
    });

    test('falls back to sender_name when the display name is blank', () {
      final message = ChatMessageDTO.fromJson(
        _messageJson(senderName: 'Tenzin Dorje', senderDisplayName: '  '),
      );

      expect(message.senderName, 'Tenzin Dorje');
    });

    test('stays null when neither name is sent', () {
      final message = ChatMessageDTO.fromJson(_messageJson());

      expect(message.senderName, isNull);
    });

    test('keeps the display name through a cache round trip', () {
      final message = ChatMessageDTO.fromJson(
        _messageJson(senderName: 'Tenzin Dorje', senderDisplayName: 'tenz'),
      );

      expect(ChatMessageDTO.fromJson(message.toJson()).senderName, 'tenz');
    });

    test('the quoted message uses the display name too', () {
      final message = ChatMessageDTO.fromJson(
        _messageJson(
          parent: {
            'id': 'p1',
            'sender_id': 'u2',
            'sender_email': 'pema@example.com',
            'sender_name': 'Pema Lhamo',
            'sender_display_name': 'pema',
            'body': 'Original',
            'created_at': '2026-11-19T09:00:00Z',
          },
        ),
      );

      expect(message.parent?.senderName, 'pema');
    });
  });

  group('ChatMessageParentDTO sender name', () {
    Map<String, dynamic> parentJson({
      String? senderName,
      String? senderDisplayName,
    }) => {
      'id': 'p1',
      'sender_id': 'u2',
      'sender_email': 'pema@example.com',
      if (senderName != null) 'sender_name': senderName,
      if (senderDisplayName != null) 'sender_display_name': senderDisplayName,
      'body': 'Original',
      'created_at': '2026-11-19T09:00:00Z',
    };

    test('prefers sender_display_name over sender_name', () {
      final parent = ChatMessageParentDTO.fromJson(
        parentJson(senderName: 'Pema Lhamo', senderDisplayName: 'pema'),
      );

      expect(parent.senderName, 'pema');
    });

    test('falls back to sender_name when the display name is missing', () {
      final parent = ChatMessageParentDTO.fromJson(
        parentJson(senderName: 'Pema Lhamo'),
      );

      expect(parent.senderName, 'Pema Lhamo');
    });

    test('keeps the display name through a cache round trip', () {
      final parent = ChatMessageParentDTO.fromJson(
        parentJson(senderName: 'Pema Lhamo', senderDisplayName: 'pema'),
      );

      expect(ChatMessageParentDTO.fromJson(parent.toJson()).senderName, 'pema');
    });
  });
}
