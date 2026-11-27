import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/group_profile/presentation/providers/group_profile_providers.dart';
import 'package:flutter_pecha/features/group_profile/presentation/widgets/group_recitation_collection_row.dart';
import 'package:flutter_pecha/features/practice/data/models/my_recitation_collection_models.dart';
import 'package:flutter_pecha/features/practice/domain/entities/chant_book.dart';
import 'package:flutter_pecha/features/practice/domain/entities/space_chant.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/my_recitation_collections_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/practice_analytics.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/add_to_chant_book_sheet.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/collection_name_dialog.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/new_collection_dialog.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
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
  final navigationContext = groupRecitationCollectionNavigationContext(
    key: GroupRecitationCollectionKey(
      groupId: chant.collection.groupId,
      collectionId: chant.collection.id,
    ),
    collection: chant.collection,
    item: item,
    completionState: const GroupRecitationCollectionCompletionState(),
    play: play,
    groupName: chant.spaceName,
  );
  await context.push('/reader/$textId', extra: navigationContext);
}

/// Runs the "Chant book +" flow. Guests and expired sessions get the login
/// drawer instead: the collection endpoints need credentials, and these
/// screens are pushed imperatively, so the route guard does not re-run.
Future<void> createChantBook(BuildContext context, WidgetRef ref) async {
  if (!_ensureSignedIn(context, ref, feature: 'chant_book_create')) return;
  try {
    await showNewCollectionDialog(context);
  } finally {
    if (context.mounted) _invalidateMyChantBooks(ref);
  }
}

/// A chant row's ⋮ or long-press: the Add to chant book sheet, then either
/// a new chant book holding [chant] (named after it, renamable first) or
/// [chant] added to one of the user's books. Does nothing for a chant
/// without a text id; guests get the login drawer.
Future<void> addChantToChantBook(
  BuildContext context,
  WidgetRef ref,
  RecitationModel chant,
) async {
  if (chant.textId.trim().isEmpty) return;
  if (!_ensureSignedIn(context, ref, feature: 'chant_book_add_chant')) return;

  // The row can be rebuilt away while the sheets are up or a request runs;
  // the container and messenger outlive it.
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);

  final choice = await showAddToChantBookSheet(context, chant: chant);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case NewChantBookChoice():
      await _createChantBookWith(context, container, messenger, chant);
    case ExistingChantBookChoice(:final book):
      await _addToChantBook(context, container, messenger, chant, book);
  }
}

/// The New chant book sheet, then the book with [chant] in it. It lands in
/// My chant books; the user opens it from there.
Future<void> _createChantBookWith(
  BuildContext context,
  ProviderContainer container,
  ScaffoldMessengerState messenger,
  RecitationModel chant,
) async {
  final l10n = context.l10n;
  final name = await showCollectionNameSheet(
    context,
    title: l10n.chant_book_new_title,
    actionLabel: l10n.my_recitation_collection_create,
    hintText: l10n.chant_book_name_hint,
  );
  if (name == null) return;

  final result = await container
      .read(myRecitationCollectionsRepositoryProvider)
      .createCollectionWithItems(
        name: name,
        imgUrl: '',
        textIds: [chant.textId],
      );
  // Even a partial failure leaves a book on the server to show.
  _invalidateMyChantBooksIn(container);
  result.fold(
    (_) => messenger.showSnackBar(
      SnackBar(content: Text(l10n.something_went_wrong)),
    ),
    (collection) => container
        .read(practiceAnalyticsProvider)
        .collectionCreated(
          collectionId: collection.id,
          itemCount: 1,
          hasImage: false,
        ),
  );
}

/// Adds [chant] to [book], then says so with a View action that opens it.
Future<void> _addToChantBook(
  BuildContext context,
  ProviderContainer container,
  ScaffoldMessengerState messenger,
  RecitationModel chant,
  MyRecitationCollectionModel book,
) async {
  final l10n = context.l10n;
  final router = GoRouter.of(context);
  final result = await container
      .read(myRecitationCollectionsRepositoryProvider)
      .addItemsToCollection(collectionId: book.id, textIds: [chant.textId]);
  container.invalidate(myRecitationCollectionDetailProvider(book.id));
  _invalidateMyChantBooksIn(container);
  result.fold(
    (_) => messenger.showSnackBar(
      SnackBar(content: Text(l10n.something_went_wrong)),
    ),
    (_) {
      container
          .read(practiceAnalyticsProvider)
          .collectionUpdated(
            collectionId: book.id,
            itemCount: book.itemCount + 1,
            itemsAdded: 1,
            itemsRemoved: 0,
            reordered: false,
            renamed: false,
            imageChanged: false,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.chant_book_added_to(book.name)),
          action: SnackBarAction(
            label: l10n.chant_book_view,
            onPressed:
                () => router.pushNamed(
                  'my-recitation-collection',
                  pathParameters: {'collectionId': book.id},
                  extra: {'title': book.name},
                ),
          ),
        ),
      );
    },
  );
}

bool _ensureSignedIn(
  BuildContext context,
  WidgetRef ref, {
  required String feature,
}) {
  final auth = ref.read(authProvider);
  if (auth.isGuest || !auth.isLoggedIn) {
    LoginDrawer.show(context, ref, feature: feature);
    return false;
  }
  return true;
}

void _invalidateMyChantBooks(WidgetRef ref) {
  ref.invalidate(myChantBooksProvider);
  ref.invalidate(myChantBooksPagedProvider);
}

void _invalidateMyChantBooksIn(ProviderContainer container) {
  container.invalidate(myChantBooksProvider);
  container.invalidate(myChantBooksPagedProvider);
}
