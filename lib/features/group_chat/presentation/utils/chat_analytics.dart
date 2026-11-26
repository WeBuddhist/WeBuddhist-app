import 'dart:async';

import 'package:flutter_pecha/core/analytics/analytics_events.dart';
import 'package:flutter_pecha/core/analytics/analytics_providers.dart';
import 'package:flutter_pecha/core/analytics/analytics_service.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/group_chat/domain/prayer_room_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('GroupChatAnalytics');

/// How the screen came to have a room, carried on `group_chat_opened`.
enum ChatOpenSource {
  /// The lookup on open found the group's existing room.
  resolved,

  /// This member's first send created the room.
  firstSend,
}

/// What a confirmed reaction toggle did on the server.
enum ChatReactionAction { added, removed, swapped }

/// Names the toggle from the same flags that chose its request, so the label
/// always describes the call that was actually sent: a DELETE is a removal,
/// a POST that replaces another emoji is a swap, any other POST is an add.
ChatReactionAction chatReactionActionFor({
  required bool isRemoval,
  required bool isSwap,
}) {
  if (isRemoval) return ChatReactionAction.removed;
  if (isSwap) return ChatReactionAction.swapped;
  return ChatReactionAction.added;
}

/// Fires `group_chat_opened` at most once for one screen.
///
/// Kept out of the screen so the rule can be tested without a socket, a room
/// lookup and a signed-in session behind it.
class ChatOpenTracker {
  bool _tracked = false;

  void track(
    GroupChatAnalytics analytics, {
    required String groupId,
    required String roomId,
    required ChatOpenSource source,
    required bool screenDisposed,
  }) {
    if (_tracked || roomId.isEmpty) return;
    // A late socket frame or lookup for a screen that is gone is not an open.
    // This member's own first send is: the server has the message, so the
    // chat was used whether or not they stayed to see it.
    if (screenDisposed && source != ChatOpenSource.firstSend) return;
    _tracked = true;
    analytics.chatOpened(groupId: groupId, roomId: roomId, source: source);
  }
}

/// Product analytics for group chat: one method per tracked action, so the
/// event names and their property keys live in one place.
///
/// Every method fires and forgets. Analytics must never delay a chat action
/// or turn a success into a failure, so a rejected capture is only logged.
/// Callers fire these after the server confirms, never optimistically.
class GroupChatAnalytics {
  GroupChatAnalytics(this._analytics);

  final AnalyticsService _analytics;

  /// Rooms opened this session, so message actions can name their group.
  final Map<String, String> _groupByRoom = {};

  /// The screen has a room to talk in. Fired once per screen open by the
  /// screen itself, so it counts visits, not new members; [source] says how
  /// the room was found.
  void chatOpened({
    required String groupId,
    required String roomId,
    required ChatOpenSource source,
  }) {
    _groupByRoom[roomId] = groupId;
    _track(AnalyticsEvents.groupChatOpened, {
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.source: source.name,
    });
  }

  /// A message was accepted by the server. A reply is still a sent message,
  /// so it fires `group_message_sent` too, and `group_message_replied` on top.
  void messageSent({
    required String groupId,
    required String roomId,
    required String messageId,
    String? parentMessageId,
  }) {
    final isReply = parentMessageId != null && parentMessageId.isNotEmpty;
    _track(AnalyticsEvents.groupMessageSent, {
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
      AnalyticsProperties.isReply: isReply,
    });
    if (!isReply) return;
    _track(AnalyticsEvents.groupMessageReplied, {
      AnalyticsProperties.groupId: groupId,
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
      AnalyticsProperties.parentMessageId: parentMessageId,
    });
  }

  /// One event per message, whether it went through the bulk route or the
  /// one-call-each fallback.
  void messageDeleted({required String roomId, required String messageId}) {
    _track(AnalyticsEvents.groupMessageDeleted, {
      AnalyticsProperties.groupId: _groupByRoom[roomId],
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
    });
  }

  void messageReacted({
    required String roomId,
    required String messageId,
    required String emoji,
    required ChatReactionAction action,
  }) {
    _track(AnalyticsEvents.groupMessageReacted, {
      AnalyticsProperties.groupId: _groupByRoom[roomId],
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
      AnalyticsProperties.emoji: emoji,
      AnalyticsProperties.action: action.name,
    });
  }

  /// [reason] is the wire value sent to the server, not the localized label.
  void messageReported({
    required String roomId,
    required String messageId,
    required String reason,
  }) {
    _track(AnalyticsEvents.groupMessageReported, {
      AnalyticsProperties.groupId: _groupByRoom[roomId],
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
      AnalyticsProperties.reason: reason,
    });
  }

  /// The server accepted a new prayer request. Its text and intention are
  /// personal, so only the ids are sent.
  void prayerRequestCreated({
    required PrayerRoomScope scope,
    required String roomId,
    required String messageId,
  }) {
    _track(AnalyticsEvents.prayerRequestCreated, {
      ..._scopeProperties(scope),
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
    });
  }

  /// The server confirmed a pray call. Taps are sent in batches, so
  /// [prayerCount] says how many prayers this call carried: add it up rather
  /// than counting events.
  void prayerRequestPrayed({
    required PrayerRoomScope scope,
    required String roomId,
    required String messageId,
    required int prayerCount,
  }) {
    _track(AnalyticsEvents.prayerRequestPrayed, {
      ..._scopeProperties(scope),
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
      AnalyticsProperties.prayerCount: prayerCount,
    });
  }

  /// The owner marked their request accomplished. [scope] is null from "My
  /// prayer requests", which lists requests across every room.
  void prayerRequestCompleted({
    PrayerRoomScope? scope,
    required String roomId,
    required String messageId,
  }) {
    _track(AnalyticsEvents.prayerRequestCompleted, {
      ..._scopeProperties(scope),
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
    });
  }

  /// The owner opened who is praying for their request. [prayerCount] is the
  /// request's total when opened. [scope] is null as for
  /// [prayerRequestCompleted].
  void prayerSupportersViewed({
    PrayerRoomScope? scope,
    required String roomId,
    required String messageId,
    required int prayerCount,
  }) {
    _track(AnalyticsEvents.prayerSupportersViewed, {
      ..._scopeProperties(scope),
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
      AnalyticsProperties.prayerCount: prayerCount,
    });
  }

  /// "A prayer for you" opened, which deals a random request to pray for.
  void prayerRandomOpened({required PrayerRoomScope scope}) {
    _track(AnalyticsEvents.prayerRandomOpened, _scopeProperties(scope));
  }

  Map<String, Object?> _scopeProperties(PrayerRoomScope? scope) => {
    AnalyticsProperties.groupId: scope?.groupId,
    AnalyticsProperties.eventId: scope?.eventId,
  };

  /// A one-to-one chat screen opened. Direct rooms have no group, so they get
  /// their own events instead of the group chat ones.
  void directChatOpened({required String roomId}) {
    _track(AnalyticsEvents.directChatOpened, {
      AnalyticsProperties.roomId: roomId,
    });
  }

  /// The server accepted a message in a one-to-one chat.
  void directMessageSent({
    required String roomId,
    required String messageId,
    required bool isReply,
  }) {
    _track(AnalyticsEvents.directMessageSent, {
      AnalyticsProperties.roomId: roomId,
      AnalyticsProperties.messageId: messageId,
      AnalyticsProperties.isReply: isReply,
    });
  }

  /// The chat list (inbox) opened. [hasUnread] is what the list last
  /// showed; null when it hasn't loaded yet.
  void chatsListOpened({bool? hasUnread}) {
    _track(AnalyticsEvents.chatsListOpened, {
      if (hasUnread != null) AnalyticsProperties.hasUnread: hasUnread,
    });
  }

  /// A prayer-request list opened: an event's or a space's sheet, or the
  /// user's own list (`scope: mine`). [source] says what opened it.
  void prayerRequestsOpened({
    required String scope,
    String? eventId,
    String? groupId,
    String? source,
  }) {
    _track(AnalyticsEvents.prayerRequestsOpened, {
      AnalyticsProperties.scope: scope,
      if (eventId != null) AnalyticsProperties.eventId: eventId,
      if (groupId != null) AnalyticsProperties.groupId: groupId,
      if (source != null) AnalyticsProperties.source: source,
    });
  }

  void _track(String event, Map<String, Object?> properties) {
    unawaited(
      _analytics.track(event, properties: properties).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _logger.warning('Failed to track $event', error, stackTrace);
      }),
    );
  }
}

final groupChatAnalyticsProvider = Provider<GroupChatAnalytics>((ref) {
  return GroupChatAnalytics(ref.watch(analyticsServiceProvider));
});
