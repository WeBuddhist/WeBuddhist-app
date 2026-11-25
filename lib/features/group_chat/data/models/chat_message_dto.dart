import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_visible_name.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_parent_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_reaction_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_translation_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_prayer_intention_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_prayer_request_source_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_prayer_user_dto.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_message_media.dart';

class ChatMessageDTO extends Equatable {
  /// `message_type` values the API accepts.
  static const String typeText = 'TEXT';
  static const String typePrayer = 'PRAYER';

  final String id;
  final String roomId;
  final String senderId;
  final String senderEmail;

  /// Display identity carried by the message itself. Null on rows written
  /// before the API supplied it, which is what keeps the directory lookup and
  /// the email fallback alive.
  final String? senderName;
  final String? senderAvatarUrl;
  final String body;
  final String createdAt;

  /// When the sender deleted this message, or null while it stands.
  ///
  /// Optional on the wire, and [body] stays required beside it — a deleted
  /// message can still arrive carrying its original text. Everything that
  /// decides whether a message is gone reads this field, never an empty body.
  final String? deletedAt;

  final ChatMessageParentDTO? parent;
  final List<ChatMessageReactionDTO> reactions;
  final List<ChatMessageMedia> media;

  /// `TEXT` or `PRAYER`; rows from before the field existed read as `TEXT`.
  final String messageType;

  /// Only carried on a `PRAYER` message.
  final ChatPrayerIntentionDTO? intention;

  /// People praying; [totalPrayerCount] counts every prayer, repeats too.
  final int prayerCount;
  final int totalPrayerCount;
  final bool prayedByMe;

  /// The viewer's own prayers for this request.
  final int myPrayerCount;
  final List<ChatPrayerUserDTO> recentPrayers;

  /// Language the server detected for [body], e.g. `ZH`; null until it has.
  final String? sourceLanguage;

  /// [body] in the language the list was requested with, when it was.
  final ChatMessageTranslationDTO? translation;
  final bool canTranslate;

  /// Local-only fields for media uploads
  final bool isOptimisticSending;
  final bool isOptimisticFailed;
  final int sendingProgressCurrent;
  final int sendingProgressTotal;
  final List<String>? optimisticLocalFilePaths;

  /// An accomplished request stays listed with its counts; nobody prays for it.
  final bool isCompleted;
  final String? completedAt;

  /// Where one of the viewer's own requests was posted. Only
  /// `GET /chat/prayer-requests/me` carries these; [group] is null once the
  /// space is deleted, and [event] is set only for requests made in an event.
  final PrayerRequestGroupDTO? group;
  final PrayerRequestEventDTO? event;

  const ChatMessageDTO({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderEmail,
    this.senderName,
    this.senderAvatarUrl,
    required this.body,
    required this.createdAt,
    this.deletedAt,
    this.parent,
    this.reactions = const [],
    this.media = const [],
    this.messageType = typeText,
    this.intention,
    this.prayerCount = 0,
    this.totalPrayerCount = 0,
    this.prayedByMe = false,
    this.myPrayerCount = 0,
    this.recentPrayers = const [],
    this.sourceLanguage,
    this.translation,
    this.canTranslate = false,
    this.isOptimisticSending = false,
    this.isOptimisticFailed = false,
    this.sendingProgressCurrent = 0,
    this.sendingProgressTotal = 0,
    this.optimisticLocalFilePaths,
    this.isCompleted = false,
    this.completedAt,
    this.group,
    this.event,
  });

  bool get isPrayerRequest => messageType == typePrayer;

  /// [body] in the viewer's language, once the server has it.
  String? get translatedBody {
    final translation = this.translation;
    if (!canTranslate || translation == null || !translation.isReady) {
      return null;
    }
    return translation.body;
  }

  factory ChatMessageDTO.fromJson(Map<String, dynamic> json) {
    final parentJson = json['parent'];
    final intentionJson = json['intention'];
    final translationJson = json['translation'];
    final prayerCount = json['prayer_count'];
    final totalPrayerCount = json['total_prayer_count'];
    final myPrayerCount = json['my_prayer_count'];
    final groupJson = json['group'];
    final eventJson = json['event'];
    return ChatMessageDTO(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderEmail: json['sender_email'] as String? ?? '',
      senderName: _senderNameFromJson(json),
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      deletedAt: json['deleted_at'] as String?,
      parent:
          parentJson is Map<String, dynamic>
              ? ChatMessageParentDTO.fromJson(parentJson)
              : null,
      reactions:
          (json['reactions'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatMessageReactionDTO.fromJson)
              .toList() ??
          const [],
      media: (json['media'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatMessageMedia.fromJson)
              .toList() ??
          const [],
      messageType: json['message_type'] as String? ?? typeText,
      intention:
          intentionJson is Map<String, dynamic>
              ? ChatPrayerIntentionDTO.fromJson(intentionJson)
              : null,
      prayerCount: prayerCount is num ? prayerCount.toInt() : 0,
      totalPrayerCount: totalPrayerCount is num ? totalPrayerCount.toInt() : 0,
      prayedByMe: json['prayed_by_me'] as bool? ?? false,
      myPrayerCount: myPrayerCount is num ? myPrayerCount.toInt() : 0,
      recentPrayers:
          (json['recent_prayers'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatPrayerUserDTO.fromJson)
              .toList() ??
          const [],
      sourceLanguage: json['source_language'] as String?,
      translation:
          translationJson is Map<String, dynamic>
              ? ChatMessageTranslationDTO.fromJson(translationJson)
              : null,
      canTranslate: json['can_translate'] as bool? ?? false,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] as String?,
      group:
          groupJson is Map<String, dynamic>
              ? PrayerRequestGroupDTO.fromJson(groupJson)
              : null,
      event:
          eventJson is Map<String, dynamic>
              ? PrayerRequestEventDTO.fromJson(eventJson)
              : null,
    );
  }

  /// A row of the viewer's own requests (`GET /chat/prayer-requests/me`).
  /// It names no sender, since the caller is the sender, and no type.
  factory ChatMessageDTO.fromMyPrayerRequestJson(Map<String, dynamic> json) {
    return ChatMessageDTO.fromJson({...json, 'message_type': typePrayer});
  }

  /// Additive: only the fields a live update rewrites are parameterised, so
  /// the task 0 round-trip tests are untouched.
  ///
  /// [deletedAt] only ever goes from null to a timestamp — nothing undeletes a
  /// message — so the usual `?? this` idiom loses nothing here.
  /// [clearTranslation] drops the translation and detected language a new
  /// body has made stale, unless new ones are passed with it.
  /// [clearCompletedAt] drops the completion time of a request made active
  /// again.
  ChatMessageDTO copyWith({
    String? body,
    String? deletedAt,
    ChatMessageParentDTO? parent,
    List<ChatMessageReactionDTO>? reactions,
    List<ChatMessageMedia>? media,
    ChatPrayerIntentionDTO? intention,
    int? prayerCount,
    int? totalPrayerCount,
    bool? prayedByMe,
    int? myPrayerCount,
    List<ChatPrayerUserDTO>? recentPrayers,
    String? sourceLanguage,
    ChatMessageTranslationDTO? translation,
    bool? canTranslate,
    bool clearTranslation = false,
    bool? isOptimisticSending,
    bool? isOptimisticFailed,
    int? sendingProgressCurrent,
    int? sendingProgressTotal,
    List<String>? optimisticLocalFilePaths,
    bool? isCompleted,
    String? completedAt,
    bool clearCompletedAt = false,
  }) {
    return ChatMessageDTO(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderEmail: senderEmail,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      body: body ?? this.body,
      createdAt: createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      parent: parent ?? this.parent,
      reactions: reactions ?? this.reactions,
      media: media ?? this.media,
      messageType: messageType,
      intention: intention ?? this.intention,
      prayerCount: prayerCount ?? this.prayerCount,
      totalPrayerCount: totalPrayerCount ?? this.totalPrayerCount,
      prayedByMe: prayedByMe ?? this.prayedByMe,
      myPrayerCount: myPrayerCount ?? this.myPrayerCount,
      recentPrayers: recentPrayers ?? this.recentPrayers,
      sourceLanguage:
          sourceLanguage ?? (clearTranslation ? null : this.sourceLanguage),
      translation: translation ?? (clearTranslation ? null : this.translation),
      canTranslate: canTranslate ?? this.canTranslate,
      isOptimisticSending: isOptimisticSending ?? this.isOptimisticSending,
      isOptimisticFailed: isOptimisticFailed ?? this.isOptimisticFailed,
      sendingProgressCurrent: sendingProgressCurrent ?? this.sendingProgressCurrent,
      sendingProgressTotal: sendingProgressTotal ?? this.sendingProgressTotal,
      optimisticLocalFilePaths: optimisticLocalFilePaths ?? this.optimisticLocalFilePaths,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? (clearCompletedAt ? null : this.completedAt),
      group: group,
      event: event,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'sender_email': senderEmail,
      if (senderName != null) 'sender_name': senderName,
      if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
      'body': body,
      'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (parent != null) 'parent': parent!.toJson(),
      'reactions': reactions.map((reaction) => reaction.toJson()).toList(),
      'media': media.map((m) => m.toJson()).toList(),
      'message_type': messageType,
      if (isPrayerRequest) ...{
        if (intention != null) 'intention': intention!.toJson(),
        'prayer_count': prayerCount,
        'total_prayer_count': totalPrayerCount,
        'prayed_by_me': prayedByMe,
        'my_prayer_count': myPrayerCount,
        'recent_prayers': recentPrayers.map((user) => user.toJson()).toList(),
        'is_completed': isCompleted,
        if (completedAt != null) 'completed_at': completedAt,
      },
      if (sourceLanguage != null) 'source_language': sourceLanguage,
      if (translation != null) 'translation': translation!.toJson(),
      'can_translate': canTranslate,
      if (group != null) 'group': group!.toJson(),
      if (event != null) 'event': event!.toJson(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    roomId,
    senderId,
    senderEmail,
    senderName,
    senderAvatarUrl,
    body,
    createdAt,
    deletedAt,
    parent,
    reactions,
    media,
    messageType,
    intention,
    prayerCount,
    totalPrayerCount,
    prayedByMe,
    myPrayerCount,
    recentPrayers,
    sourceLanguage,
    translation,
    canTranslate,
    isOptimisticSending,
    isOptimisticFailed,
    sendingProgressCurrent,
    sendingProgressTotal,
    optimisticLocalFilePaths,
    isCompleted,
    completedAt,
    group,
    event,
  ];
}

/// The sender's display name from Edit profile, then `sender_name` for
/// messages without one.
String? _senderNameFromJson(Map<String, dynamic> json) =>
    chatVisibleName(json['sender_display_name'], json['sender_name']);
