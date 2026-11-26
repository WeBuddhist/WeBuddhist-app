import 'package:equatable/equatable.dart';
import 'package:flutter_pecha/features/group_chat/data/models/chat_visible_name.dart';

class ChatMessageReactionUserDTO extends Equatable {
  final String userId;
  final String? email;

  /// The name to show: their display name, then first and last name.
  final String? name;

  const ChatMessageReactionUserDTO({
    required this.userId,
    this.email,
    this.name,
  });

  factory ChatMessageReactionUserDTO.fromJson(Map<String, dynamic> json) {
    return ChatMessageReactionUserDTO(
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String?,
      name: chatVisibleName(json['display_name'], json['name']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
    };
  }

  @override
  List<Object?> get props => [userId, email, name];
}
