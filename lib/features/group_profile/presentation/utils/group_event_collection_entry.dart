import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';

/// Reader context for an event's recitation collection: every text on one
/// page, top to bottom, with the Sections pill to jump between them, the
/// way a plan task with several texts reads.
///
/// Carries the event so the reader follows the live recitation (in person)
/// or leaves that to the stream (online). Finish completes every chant, as
/// it does a combined plan task. [readOnly] opens it before joining: with no
/// collection id, nothing is marked complete. [liveSegmentId] is used only
/// when the live text is the first one, since the reader opens at the top.
///
/// [collection] must have at least one item.
NavigationContext groupEventCollectionNavigationContext({
  required String eventId,
  required GroupRecitationCollectionKey key,
  required GroupRecitationCollection collection,
  required GroupRecitationCollectionCompletionState completionState,
  required bool isOnlineAttendee,
  String? groupName,
  String? liveTextId,
  String? liveSegmentId,
  bool readOnly = false,
}) {
  final items = collection.items;
  final item = PlanTextItem.sources(
    sources: [
      for (final chant in items)
        PlanSourceRef(
          textId: chant.textId,
          subtaskId: chant.id,
          isCompleted: !readOnly && completionState.isCompleted(chant.id),
        ),
    ],
    title: collection.name,
    language: items.first.language,
  );
  final onLiveText = liveTextId != null && items.first.textId == liveTextId;
  return NavigationContext(
    source: NavigationSource.groupRecitationCollection,
    planTextItems: [item],
    currentTextIndex: 0,
    targetSegmentId: onLiveText ? liveSegmentId : null,
    groupId: key.groupId,
    groupTitle: groupName,
    collectionId: readOnly ? null : key.collectionId,
    collectionImageUrl: collection.imageUrl,
    language: items.first.language,
    eventId: eventId,
    isOnlineAttendee: isOnlineAttendee,
  );
}
