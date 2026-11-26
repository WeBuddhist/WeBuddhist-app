import 'package:flutter_pecha/features/connect/data/models/connect_post_comment_model.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_reaction_user_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_prayer_user_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_room_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_visible_name.dart';
import 'package:flutter_pecha/features/home/data/models/verse_of_day_engagement_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A user is shown by the display name they picked in Edit profile. First
/// and last name are only for a user who has not picked one.
///
/// One case per place the backend sends `display_name`, each with a payload
/// that has it and one that does not (the backend sends null then).
void main() {
  group('verse of the day', () {
    Map<String, dynamic> comment({String? displayName}) => {
      'id': 'c1',
      'verse_id': 'v1',
      'user_id': 'u1',
      'text': 'Sadhu',
      'user': {
        'first_name': 'Tenzin',
        'last_name': 'Dhakar',
        'display_name': displayName,
      },
    };

    test('a comment shows its author by display name', () {
      final author =
          VerseOfDayCommentModel.fromJson(
            comment(displayName: 'Ani Pema'),
          ).toEntity().user;

      expect(author.displayName, 'Ani Pema');
    });

    test('an author without one is shown by first and last name', () {
      for (final none in [null, '', '   ']) {
        final author =
            VerseOfDayCommentModel.fromJson(
              comment(displayName: none),
            ).toEntity().user;

        expect(author.displayName, 'Tenzin Dhakar', reason: '"$none"');
      }
    });

    test('a comment whose user is missing still has a name to show', () {
      final author =
          VerseOfDayCommentModel.fromJson({
            'id': 'c1',
            'verse_id': 'v1',
            'text': 'x',
          }).toEntity().user;

      expect(author.displayName, 'User');
    });

    test('people who liked a verse or a comment are listed by display name', () {
      final liker =
          VerseOfDayLikerModel.fromJson({
            'user_id': 'u1',
            'first_name': 'Tenzin',
            'last_name': 'Dhakar',
            'display_name': 'Ani Pema',
          }).toEntity().user;
      final unnamed =
          VerseOfDayLikerModel.fromJson({
            'user_id': 'u2',
            'first_name': 'Tenzin',
            'last_name': null,
            'display_name': null,
          }).toEntity().user;

      expect(liker.displayName, 'Ani Pema');
      expect(unnamed.displayName, 'Tenzin');
    });
  });

  group('community post comments', () {
    Map<String, dynamic> comment(Map<String, dynamic> user) => {
      'id': 'c1',
      'post_id': 'p1',
      'text': 'Sadhu',
      'user': user,
    };

    test('a comment shows its author by display name, as typed', () {
      final author =
          ConnectPostCommentModel.fromJson(
            comment({
              'first_name': 'tenzin',
              'last_name': 'dhakar',
              'display_name': ' ani pema ',
              'email': 'tenzin@example.com',
            }),
          ).toEntity().user;

      // Not re-capitalised: it is the name its owner chose.
      expect(author.displayName, 'ani pema');
    });

    test('without one: first and last name, then the email name', () {
      final named =
          ConnectPostCommentModel.fromJson(
            comment({
              'first_name': 'tenzin',
              'last_name': 'dhakar',
              'display_name': null,
              'email': 'tenzin@example.com',
            }),
          ).toEntity().user;
      final unnamed =
          ConnectPostCommentModel.fromJson(
            comment({'email': 'pema.lhamo@example.com'}),
          ).toEntity().user;

      expect(named.displayName, 'Tenzin Dhakar');
      expect(unnamed.displayName, 'Pema.lhamo');
    });
  });

  group('chat', () {
    test('a message shows its sender by display name', () {
      final message = ChatMessageDTO.fromJson({
        'id': 'm1',
        'sender_name': 'Tenzin Dhakar',
        'sender_display_name': 'Ani Pema',
      });
      final unnamed = ChatMessageDTO.fromJson({
        'id': 'm2',
        'sender_name': 'Tenzin Dhakar',
        'sender_display_name': null,
      });

      expect(message.senderName, 'Ani Pema');
      expect(unnamed.senderName, 'Tenzin Dhakar');
    });

    test('who reacted is listed by display name', () {
      final user = ChatMessageReactionUserDTO.fromJson({
        'user_id': 'u1',
        'name': 'Tenzin Dhakar',
        'display_name': 'Ani Pema',
      });
      final unnamed = ChatMessageReactionUserDTO.fromJson({
        'user_id': 'u2',
        'name': 'Tenzin Dhakar',
      });

      expect(user.name, 'Ani Pema');
      expect(unnamed.name, 'Tenzin Dhakar');
    });

    test('who prayed is listed by display name', () {
      final user = ChatPrayerUserDTO.fromJson({
        'user_id': 'u1',
        'name': 'Tenzin Dhakar',
        'display_name': 'Ani Pema',
      });
      final unnamed = ChatPrayerUserDTO.fromJson({
        'user_id': 'u2',
        'name': 'Tenzin Dhakar',
        'display_name': '',
      });

      expect(user.name, 'Ani Pema');
      expect(unnamed.name, 'Tenzin Dhakar');
    });

    test('a direct message is titled with the other person\'s display name', () {
      final room = ChatRoomDTO.fromJson({
        'id': 'r1',
        'kind': 'DIRECT',
        'other_user_id': 'u2',
        'other_user_name': 'Tenzin Dhakar',
        'other_user_display_name': 'Ani Pema',
      });
      final unnamed = ChatRoomDTO.fromJson({
        'id': 'r2',
        'kind': 'DIRECT',
        'other_user_id': 'u3',
        'other_user_name': 'Tenzin Dhakar',
      });

      expect(room.otherUserName, 'Ani Pema');
      expect(unnamed.otherUserName, 'Tenzin Dhakar');
    });

    test('the chosen name survives the cache round trip', () {
      // Cached rooms and reactions are written with the name already chosen,
      // and carry no display-name key of their own.
      final room = ChatRoomDTO.fromJson(
        ChatRoomDTO.fromJson({
          'id': 'r1',
          'kind': 'DIRECT',
          'other_user_name': 'Tenzin Dhakar',
          'other_user_display_name': 'Ani Pema',
        }).toJson(),
      );
      final reactor = ChatMessageReactionUserDTO.fromJson(
        ChatMessageReactionUserDTO.fromJson({
          'user_id': 'u1',
          'name': 'Tenzin Dhakar',
          'display_name': 'Ani Pema',
        }).toJson(),
      );

      expect(room.otherUserName, 'Ani Pema');
      expect(reactor.name, 'Ani Pema');
    });

    test('chatVisibleName: display name, then name, then nothing', () {
      expect(chatVisibleName(' Ani Pema ', 'Tenzin Dhakar'), 'Ani Pema');
      expect(chatVisibleName(null, 'Tenzin Dhakar'), 'Tenzin Dhakar');
      expect(chatVisibleName('  ', 'Tenzin Dhakar'), 'Tenzin Dhakar');
      expect(chatVisibleName(7, 'Tenzin Dhakar'), 'Tenzin Dhakar');
      expect(chatVisibleName(null, null), isNull);
    });
  });
}
