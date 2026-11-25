import 'package:flutter_pecha/features/group_chat/domain/repositories/group_chat_repository.dart';

/// Deletes server-side pending chat media when upload is abandoned or send fails.
Future<void> deletePendingChatMedia(
  GroupChatRepository repository,
  List<String> mediaIds,
) async {
  for (final id in mediaIds) {
    final result = await repository.deleteChatMedia(id);
    result.fold((_) {}, (_) {});
  }
}