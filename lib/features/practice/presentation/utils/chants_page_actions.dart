import 'package:flutter/widgets.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_recitation_collection_row.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/new_collection_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens a chant book from the Chants page or a See-all screen: the user's
/// own in the my-collection screen, a space's in the space collection
/// screen. Returns once the user comes back.
Future<void> openChantBook(
  BuildContext context,
  WidgetRef ref,
  ChantBook book,
) async {
  final extra = {'title': book.name};
  switch (book.source) {
    case ChantBookSource.personal:
      await context.pushNamed(
        'my-recitation-collection',
        pathParameters: {'collectionId': book.id},
        extra: extra,
      );
      // The book may have been renamed, edited or deleted there.
      if (context.mounted) _invalidateMyChantBooks(ref);
    case ChantBookSource.space:
      final groupId = book.groupId;
      if (groupId != null) {
        await context.pushNamed(
          'home-group-recitation-collection',
          pathParameters: {'groupId': groupId, 'collectionId': book.id},
          extra: extra,
        );
      } else {
        await context.pushNamed(
          'recitation-collection',
          pathParameters: {'collectionId': book.id},
          extra: extra,
        );
      }
  }
}

/// Opens a space chant in the reader the way its chant book screen does,
/// so next / previous step through the book and its recordings come along.
/// With [play] the first recording starts at once.
///
/// Today's completions are not loaded here, so the reader's chant list
/// starts with none ticked; marking one complete still works.
Future<void> openSpaceChant(
  BuildContext context,
  SpaceChant chant, {
  bool play = false,
}) async {
  final item = chant.item;
  final textId = item.textId.trim();
  if (textId.isEmpty || item.id.trim().isEmpty) return;
  final tracks = collectionAudioTracksFor(item);
  final navigationContext = groupRecitationCollectionNavigationContext(
    key: GroupRecitationCollectionKey(
      groupId: chant.collection.groupId,
      collectionId: chant.collection.id,
    ),
    collection: chant.collection,
    item: item,
    completionState: const GroupRecitationCollectionCompletionState(),
    initialAudio: play && tracks.isNotEmpty ? tracks.first : null,
    groupName: chant.spaceName,
  );
  await context.push('/reader/$textId', extra: navigationContext);
}

/// Runs the "Chant book +" flow. Guests and expired sessions get the login
/// drawer instead: the collection endpoints need credentials, and these
/// screens are pushed imperatively, so the route guard does not re-run.
Future<void> createChantBook(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authProvider);
  if (auth.isGuest || !auth.isLoggedIn) {
    LoginDrawer.show(context, ref);
    return;
  }
  try {
    await showNewCollectionDialog(context);
  } finally {
    if (context.mounted) _invalidateMyChantBooks(ref);
  }
}

void _invalidateMyChantBooks(WidgetRef ref) {
  ref.invalidate(myChantBooksProvider);
  ref.invalidate(myChantBooksPagedProvider);
}
