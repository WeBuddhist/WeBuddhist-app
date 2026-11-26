/// Backend moderation / profanity-filter codes for group chat.
class ChatModeration {
  ChatModeration._();

  static const inappropriateLanguage = 'INAPPROPRIATE_LANGUAGE';

  /// The message being replied to no longer exists — deleted, or never valid.
  static const invalidParentMessage = 'INVALID_PARENT_MESSAGE_ID';

  /// A new prayer request in a finished event's room (400). Ordinary chat
  /// messages there are still accepted.
  static const eventEnded = 'EVENT_ENDED';

  static bool isInappropriateLanguage(String? code) =>
      code == inappropriateLanguage;

  static bool isInvalidParentMessage(String? code) =>
      code == invalidParentMessage;

  static bool isEventEnded(String? code) => code == eventEnded;
}
