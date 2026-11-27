import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_pecha/core/analytics/share_analytics.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/deep_linking/deep_link_url_builder.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/services/share_url/share_url_service.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/core/utils/get_language.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/core/widgets/collection_completion_sheet.dart';
import 'package:flutter_pecha/core/widgets/destructive_confirmation_dialog.dart';
import 'package:flutter_pecha/core/widgets/error_state_widget.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_analytics.dart';
import 'package:flutter_pecha/features/practice/data/datasource/bookmark_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/models/my_recitation_collection_models.dart';
import 'package:flutter_pecha/features/practice/data/utils/collection_display_order_plan.dart';
import 'package:flutter_pecha/features/practice/presentation/controllers/bookmark_controller.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/bookmark_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/my_recitation_collections_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/add_chants_to_collection_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/collection_name_validation.dart';
import 'package:flutter_pecha/features/practice/presentation/utils/practice_analytics.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_book_colors.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_text.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/my_recitation_collection_options_sheet.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_pecha/shared/domain/validators/collection_name_validator.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const double _kCoverSize = 187;
const double _kPagePadding = 20;

/// The page of one of the user's chant books
/// (`GET /users/me/recitation-collections/{id}`).
///
/// The user's own book is edited in place: the camera badge changes the
/// cover, tapping the name renames it (Done saves), chants are dragged by
/// their handle to reorder and removed from their ⋮, and "Add chants" adds
/// more. Every change is saved as it is made. An imported book is someone
/// else's, so it only reads. Tapping a chant opens it in the shared reader
/// with the book's chants as its list.
class MyRecitationCollectionScreen extends ConsumerStatefulWidget {
  const MyRecitationCollectionScreen({
    super.key,
    required this.collectionId,
    this.initialTitle,
  });

  final String collectionId;
  final String? initialTitle;

  @override
  ConsumerState<MyRecitationCollectionScreen> createState() =>
      _MyRecitationCollectionScreenState();
}

class _MyRecitationCollectionScreenState
    extends ConsumerState<MyRecitationCollectionScreen> {
  static final _logger = AppLogger('MyRecitationCollectionScreen');

  bool _hasShownCompletionSheetThisVisit = false;
  bool _viewTracked = false;

  /// A save is running; further edits wait for it.
  bool _isSaving = false;

  /// The latest detail built, for saves started outside build (focus loss).
  MyRecitationCollectionDetailModel? _detail;

  bool _isEditingName = false;
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  /// Shown in place of the server's name / order while a save is on its
  /// way, so the page doesn't jump back before the refresh lands.
  String? _pendingName;
  List<MyRecitationCollectionItemModel>? _pendingOrder;

  /// The picked cover, previewed while it uploads and after.
  File? _localCover;

  /// Upright copy written for the upload; deleted once nothing shows it.
  File? _normalizedCoverTemp;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      // Tapping away saves too, as Done does.
      if (!_nameFocus.hasFocus && _isEditingName) _saveName();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    final temp = _normalizedCoverTemp;
    if (temp != null) _deleteTempFile(temp);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      myRecitationCollectionDetailProvider(widget.collectionId),
    );
    final completionState = ref.watch(
      myRecitationCollectionCompletionProvider(widget.collectionId),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = detailAsync.valueOrNull?.fold((_) => null, (value) => value);
    _detail = detail;

    _maybeShowCompletionSheet(detail, completionState);
    if (detail != null && !_viewTracked) {
      _viewTracked = true;
      ref
          .read(groupAnalyticsProvider)
          .recitationCollectionOpened(
            collectionId: widget.collectionId,
            groupId: null,
            itemCount: detail.items.length,
          );
    }

    return Scaffold(
      backgroundColor: ChantBookColors.pageBottom(isDark),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.45],
            colors: [
              ChantBookColors.pageTop(isDark),
              ChantBookColors.pageBottom(isDark),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                // An imported collection is someone else's: no edit or
                // delete.
                onMenuTap:
                    detail != null && !detail.isImported
                        ? () => MyRecitationCollectionOptionsSheet.show(
                          context,
                          collection: detail,
                        )
                        : null,
              ),
              SizedBox(
                height: 2,
                child: _isSaving ? const LinearProgressIndicator() : null,
              ),
              Expanded(
                child: detailAsync.when(
                  data:
                      (either) => either.fold(
                        (failure) =>
                            ErrorStateWidget(error: failure, onRetry: _reload),
                        (collection) => _buildContent(collection, isDark),
                      ),
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, _) =>
                          ErrorStateWidget(error: error, onRetry: _reload),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reload() =>
      ref.invalidate(myRecitationCollectionDetailProvider(widget.collectionId));

  Widget _buildContent(
    MyRecitationCollectionDetailModel collection,
    bool isDark,
  ) {
    _clearPendingOnceSaved();
    final isOwn = !collection.isImported;
    final items = _pendingOrder ?? collection.items;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    Widget row(int index) {
      final item = items[index];
      return _ChantRow(
        key: ValueKey(item.id.isNotEmpty ? item.id : item.textId),
        item: item,
        index: index,
        isDark: isDark,
        isOwn: isOwn,
        onOpen: () => _openItem(collection, item),
        onMore: () => _showChantOptions(collection, item),
      );
    }

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            _kPagePadding,
            8,
            _kPagePadding,
            12,
          ),
          sliver: SliverToBoxAdapter(
            child: _buildHeader(collection, items, isDark),
          ),
        ),
        if (isOwn)
          SliverReorderableList(
            itemCount: items.length,
            itemBuilder: (context, index) => row(index),
            // newIndex already counts the moved chant as removed.
            onReorderItem:
                (oldIndex, newIndex) =>
                    _onReorder(collection, items, oldIndex, newIndex),
            proxyDecorator:
                (child, _, _) => Material(
                  color: ChantBookColors.pageBottom(isDark),
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
          )
        else
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => row(index),
          ),
        if (isOwn)
          SliverToBoxAdapter(
            child: _AddChantsRow(
              isDark: isDark,
              onTap: () => _addChants(collection),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 32 + bottomInset)),
      ],
    );
  }

  Widget _buildHeader(
    MyRecitationCollectionDetailModel collection,
    List<MyRecitationCollectionItemModel> items,
    bool isDark,
  ) {
    final l10n = context.l10n;
    final isOwn = !collection.isImported;
    final secondary = ChantBookColors.secondaryText(isDark);
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final count = l10n.my_recitation_collection_chant_count(items.length);
    final owner = collection.ownerName?.trim() ?? '';
    final bookmarkTarget = BookmarkTarget(
      type: BookmarkType.recitationCollection,
      sourceId: collection.id,
    );
    final isBookmarked = ref.watch(isBookmarkedProvider(bookmarkTarget));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _Cover(
            imageUrl: collection.imgUrl,
            localFile: _localCover,
            isDark: isDark,
            onChange: isOwn ? () => _changeCover(collection) : null,
          ),
        ),
        const SizedBox(height: 16),
        _buildName(collection, isOwn, isDark, titleColor),
        const SizedBox(height: 6),
        Text(
          isOwn
              ? '$count · ${l10n.chant_book_yours}'
              : owner.isEmpty
              ? count
              : '$count · $owner',
          style: TextStyle(fontSize: 13, color: secondary),
        ),
        if (isOwn) ...[
          const SizedBox(height: 16),
          Text(
            l10n.chant_book_only_you,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.chant_book_private_note,
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: AppAssets.plus,
              label: l10n.nav_practice,
              isDark: isDark,
              onTap: () => _addToPractices(collection),
            ),
            _ActionChip(
              icon:
                  isBookmarked
                      ? AppAssets.bookmarkSimpleFill
                      : AppAssets.bookmarkSimple,
              label: l10n.bookmark,
              isDark: isDark,
              onTap:
                  () => BookmarkController(
                    ref: ref,
                    context: context,
                  ).toggleRecitationCollection(
                    collection.id,
                    name: collection.name,
                  ),
            ),
            _ActionChip(
              icon: AppAssets.share,
              label: l10n.share,
              isDark: isDark,
              onTap: () => _share(collection, items),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StartButton(
          isDark: isDark,
          onPressed:
              items.isEmpty ? null : () => _openItem(collection, items.first),
        ),
      ],
    );
  }

  Widget _buildName(
    MyRecitationCollectionDetailModel collection,
    bool isOwn,
    bool isDark,
    Color titleColor,
  ) {
    final name = _pendingName ?? collection.name;
    final style = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: titleColor,
    );
    if (!isOwn) return Text(name, style: style);

    if (_isEditingName) {
      final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: titleColor, width: 1.5),
      );
      return TextField(
        controller: _nameController,
        focusNode: _nameFocus,
        style: style,
        textInputAction: TextInputAction.done,
        maxLength: CollectionNameValidator.maxLength,
        buildCounter:
            (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
        onSubmitted: (_) => _saveName(),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceWhite,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      );
    }

    return Semantics(
      button: true,
      label: context.l10n.chant_book_rename,
      child: Material(
        color: ChantBookColors.nameFill(isDark),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _startRename(name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(
              name,
              style: style,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // --- Saving -------------------------------------------------------------

  /// Every write needs a session. This screen can outlive one, so check
  /// before each and offer sign-in instead of letting the request fail.
  bool _ensureSignedIn() {
    final auth = ref.read(authProvider);
    if (auth.isLoggedIn && !auth.isGuest) return true;
    LoginDrawer.show(context, ref, feature: 'recitation_collection_edit');
    return false;
  }

  /// Runs [write] with the saving bar showing, then reloads the book so the
  /// page shows what the server holds. Returns whether [write] succeeded;
  /// a failure is logged and said in a snackbar.
  Future<bool> _save(String what, Future<Failure?> Function() write) async {
    if (_isSaving || !_ensureSignedIn()) return false;
    setState(() => _isSaving = true);
    final failure = await write();
    await ref
        .read(myRecitationCollectionsRepositoryProvider)
        .refreshCollectionDetail(widget.collectionId);
    if (!mounted) return false;
    setState(() => _isSaving = false);
    if (failure != null) {
      _logger.error('Failed to $what: ${failure.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.something_went_wrong)),
      );
      return false;
    }
    return true;
  }

  /// Drops the stand-ins once no save is running: [_save] has refreshed the
  /// detail by then, so the server's values take over (after a failed save
  /// too, which puts the old ones back).
  void _clearPendingOnceSaved() {
    if (_isSaving) return;
    _pendingName = null;
    _pendingOrder = null;
  }

  void _startRename(String name) {
    if (_isSaving) return;
    _nameController.text = name;
    _nameController.selection = TextSelection.collapsed(offset: name.length);
    setState(() => _isEditingName = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  Future<void> _saveName() async {
    final collection = _detail;
    if (!_isEditingName || collection == null) return;
    setState(() => _isEditingName = false);

    final error = CollectionNameValidator.validate(_nameController.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(collectionNameErrorMessage(context.l10n, error)),
        ),
      );
      return;
    }
    final name = CollectionNameValidator.sanitize(_nameController.text)!;
    if (name == collection.name) return;

    setState(() => _pendingName = name);
    final saved = await _save(
      'rename collection',
      () async => _failureOf(
        await ref
            .read(myRecitationCollectionsRepositoryProvider)
            .updateCollection(collectionId: collection.id, name: name),
      ),
    );
    if (saved) _trackUpdate(collection, renamed: true);
  }

  Future<void> _changeCover(
    MyRecitationCollectionDetailModel collection,
  ) async {
    if (_isSaving || !_ensureSignedIn()) return;
    final source = await _pickCoverSource();
    if (source == null || !mounted) return;

    final xFile = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;

    final File file;
    try {
      file = await _normalizeCoverOrientation(xFile.path);
    } catch (e, st) {
      _logger.error('Failed to normalize cover image: $e', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.something_went_wrong)),
      );
      return;
    }
    if (!mounted) return;

    final previousTemp = _normalizedCoverTemp;
    final previousCover = _localCover;
    _normalizedCoverTemp = file.path != xFile.path ? file : null;
    setState(() => _localCover = file);
    if (previousTemp != null && previousTemp.path != file.path) {
      _deleteTempFile(previousTemp);
    }

    final repository = ref.read(myRecitationCollectionsRepositoryProvider);
    final saved = await _save('change collection cover', () async {
      final upload = await repository.uploadImage(file);
      final uploadFailure = _failureOf(upload);
      if (uploadFailure != null) return uploadFailure;
      final key = upload.fold((_) => '', (value) => value.key);
      return _failureOf(
        await repository.updateCollection(
          collectionId: collection.id,
          name: collection.name,
          imgUrl: key,
        ),
      );
    });
    if (!mounted) return;
    if (saved) {
      _trackUpdate(collection, imageChanged: true);
    } else {
      setState(() => _localCover = previousCover);
    }
  }

  Future<ImageSource?> _pickCoverSource() {
    final l10n = context.l10n;
    return showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppAssets.camera),
                  title: Text(l10n.edit_profile_take_photo),
                  onTap:
                      () => Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(AppAssets.image),
                  title: Text(l10n.edit_profile_choose_from_library),
                  onTap:
                      () => Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
    );
  }

  /// Phone photos can carry landscape pixels plus an EXIF orientation tag
  /// that the cover pipeline may ignore, so upload upright pixels.
  Future<File> _normalizeCoverOrientation(String sourcePath) async {
    final tmpDir = await getTemporaryDirectory();
    final destPath =
        '${tmpDir.path}/collection_cover_normalized_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      destPath,
      quality: 90,
      autoCorrectionAngle: true,
    );
    if (result == null) {
      _logger.warning(
        'Cover orientation normalization returned no file; using the original',
      );
      return File(sourcePath);
    }
    return File(result.path);
  }

  /// Best-effort: a failed delete only leaves the file for the OS to clear.
  void _deleteTempFile(File file) {
    file.delete().catchError((Object e) {
      _logger.warning('Failed to delete normalized cover temp file: $e');
      return file;
    });
  }

  Future<void> _onReorder(
    MyRecitationCollectionDetailModel collection,
    List<MyRecitationCollectionItemModel> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (_isSaving) return;
    if (newIndex == oldIndex) return;
    final reordered = [...items];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    if (reordered.any((item) => item.id.isEmpty)) return;

    final Map<String, double> updates;
    try {
      updates = planDisplayOrderUpdates(
        orderedKeys: [for (final item in reordered) item.id],
        currentOrders: {for (final item in items) item.id: item.displayOrder},
      );
    } on ArgumentError catch (e) {
      _logger.error('Failed to plan chant order: $e');
      return;
    }
    if (updates.isEmpty) return;

    setState(() => _pendingOrder = reordered);
    final repository = ref.read(myRecitationCollectionsRepositoryProvider);
    final saved = await _save('reorder chants', () async {
      for (final update in updates.entries) {
        final failure = _failureOf(
          await repository.updateCollectionItemDisplayOrder(
            collectionId: collection.id,
            itemId: update.key,
            displayOrder: update.value,
          ),
        );
        if (failure != null) return failure;
      }
      return null;
    });
    if (saved) _trackUpdate(collection, reordered: true);
  }

  Future<void> _showChantOptions(
    MyRecitationCollectionDetailModel collection,
    MyRecitationCollectionItemModel item,
  ) async {
    final l10n = context.l10n;
    final remove = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListTile(
              leading: const Icon(AppAssets.trash, color: AppColors.error),
              title: Text(
                l10n.chant_book_remove_chant,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
    );
    if (remove != true || !mounted) return;

    final confirmed = await showDestructiveConfirmationDialog(
      context,
      title: l10n.chant_book_remove_chant_title,
      message: l10n.chant_book_remove_chant_message(_titleOf(item)),
      confirmLabel: l10n.chant_book_remove,
    );
    if (confirmed != true || !mounted) return;

    final saved = await _save(
      'remove chant ${item.textId}',
      () async => _failureOf(
        await ref
            .read(myRecitationCollectionsRepositoryProvider)
            .deleteCollectionItem(collectionId: collection.id, itemId: item.id),
      ),
    );
    if (saved) _trackUpdate(collection, itemsRemoved: 1);
  }

  /// The add-chants picker, starting from the book's chants: chants picked
  /// are added, chants unpicked are removed.
  Future<void> _addChants(MyRecitationCollectionDetailModel collection) async {
    if (_isSaving) return;
    final current = [
      for (final item in collection.items)
        RecitationModel(
          textId: item.textId,
          title: _titleOf(item),
          language: item.language,
        ),
    ];
    final picked = await openAddChantsToCollectionScreen(
      context,
      initiallySelected: current,
    );
    if (picked == null || !mounted) return;

    final pickedIds = {for (final chant in picked) chant.textId};
    final currentIds = {for (final item in collection.items) item.textId};
    final removed = [
      for (final item in collection.items)
        if (!pickedIds.contains(item.textId) && item.id.isNotEmpty) item,
    ];
    final added = [
      for (final chant in picked)
        if (!currentIds.contains(chant.textId)) chant.textId,
    ];
    if (removed.isEmpty && added.isEmpty) return;

    final repository = ref.read(myRecitationCollectionsRepositoryProvider);
    final saved = await _save('update chants', () async {
      for (final item in removed) {
        final failure = _failureOf(
          await repository.deleteCollectionItem(
            collectionId: collection.id,
            itemId: item.id,
          ),
        );
        if (failure != null) return failure;
      }
      if (added.isEmpty) return null;
      return _failureOf(
        await repository.addItemsToCollection(
          collectionId: collection.id,
          textIds: added,
        ),
      );
    });
    if (saved) {
      _trackUpdate(
        collection,
        itemsAdded: added.length,
        itemsRemoved: removed.length,
      );
    }
  }

  void _trackUpdate(
    MyRecitationCollectionDetailModel collection, {
    int itemsAdded = 0,
    int itemsRemoved = 0,
    bool reordered = false,
    bool renamed = false,
    bool imageChanged = false,
  }) {
    ref
        .read(practiceAnalyticsProvider)
        .collectionUpdated(
          collectionId: collection.id,
          itemCount: collection.items.length + itemsAdded - itemsRemoved,
          itemsAdded: itemsAdded,
          itemsRemoved: itemsRemoved,
          reordered: reordered,
          renamed: renamed,
          imageChanged: imageChanged,
        );
  }

  // --- Actions ------------------------------------------------------------

  /// Hands the collection to the routine editor, which injects it as a
  /// RECITATION_COLLECTION session and lets the user place its time block.
  void _addToPractices(MyRecitationCollectionDetailModel collection) {
    if (ref.read(authProvider).isGuest) {
      LoginDrawer.show(
        context,
        ref,
        feature: 'recitation_collection_add_to_practices',
      );
      return;
    }
    context.pushNamed(
      'edit-routine',
      extra: {'initialMyCollection': collection},
    );
  }

  /// A personal chant book is private, so there is no link to it: the
  /// share is its name and its chants, with a link to the app.
  Future<void> _share(
    MyRecitationCollectionDetailModel collection,
    List<MyRecitationCollectionItemModel> items,
  ) async {
    final l10n = context.l10n;
    final appUrl = await resolveShareUrlRef(
      ref,
      DeepLinkUrlBuilder.homeLink().toString(),
    );
    if (!mounted) return;
    final lines = [
      l10n.chant_book_share_message(collection.name),
      for (final item in items) '• ${_titleOf(item)}',
      '',
      appUrl,
    ];
    final shareAnalytics = ref.read(shareAnalyticsProvider);
    final result = await SharePlus.instance.share(
      ShareParams(
        text: lines.join('\n'),
        sharePositionOrigin: getSharePositionOrigin(context: context),
      ),
    );
    if (ShareAnalytics.wasUsed(result)) {
      shareAnalytics.contentShared(
        surface: ShareSurface.recitationCollection,
        targetId: collection.id,
        format: 'text',
      );
    }
  }

  Future<void> _openItem(
    MyRecitationCollectionDetailModel collection,
    MyRecitationCollectionItemModel item,
  ) async {
    await _openChantReader(context, ref, widget.collectionId, collection, item);
    if (!mounted) return;
    _maybeShowCompletionSheet(
      collection,
      ref.read(myRecitationCollectionCompletionProvider(widget.collectionId)),
    );
  }

  void _maybeShowCompletionSheet(
    MyRecitationCollectionDetailModel? collection,
    MyRecitationCollectionCompletionState completionState,
  ) {
    if (_hasShownCompletionSheetThisVisit) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (collection == null || collection.items.isEmpty) return;
    if (!completionState.hasCompletedChantThisSession) return;

    final isFullyCompleted = collection.items.every(
      (item) => _isItemCompleted(completionState, item),
    );
    if (!isFullyCompleted) return;

    _hasShownCompletionSheetThisVisit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showCompletionSheet(collection.name);
    });
  }

  Future<void> _showCompletionSheet(String collectionName) async {
    final result = await ref
        .read(myRecitationCollectionsRepositoryProvider)
        .refreshCompletionDaysCount(widget.collectionId);
    if (!mounted) return;

    final dayCount = result.fold((_) => null, (count) => count);
    if (dayCount == null) {
      _hasShownCompletionSheetThisVisit = false;
      return;
    }

    showCollectionCompletionSheet(
      context,
      collectionName: collectionName,
      dayCount: dayCount,
    );
  }
}

Failure? _failureOf<T>(Either<Failure, T> result) =>
    result.fold((failure) => failure, (_) => null);

String _titleOf(MyRecitationCollectionItemModel item) =>
    item.title?.trim().isNotEmpty == true ? item.title!.trim() : item.textId;

Future<void> _openChantReader(
  BuildContext context,
  WidgetRef ref,
  String collectionId,
  MyRecitationCollectionDetailModel collection,
  MyRecitationCollectionItemModel item,
) async {
  final textId = item.textId.trim();
  if (textId.isEmpty) return;

  final completionState = ref.read(
    myRecitationCollectionCompletionProvider(collectionId),
  );
  final currentIndex = collection.items.indexWhere((i) => i.id == item.id);
  final planTextItems =
      collection.items.map((collectionItem) {
        final itemTextId = collectionItem.textId.trim();
        final title =
            collectionItem.title?.trim().isNotEmpty == true
                ? collectionItem.title!
                : itemTextId;
        return PlanTextItem.sourceReference(
          textId: itemTextId,
          title: title,
          language: collectionItem.language,
          subtaskId: collectionItem.id,
          isCompleted: _isItemCompleted(completionState, collectionItem),
        );
      }).toList();

  final language = item.language?.trim();
  final navigationContext = NavigationContext(
    source: NavigationSource.myRecitationCollection,
    planTextItems: planTextItems,
    currentTextIndex: currentIndex >= 0 ? currentIndex : 0,
    collectionId: collectionId,
    language: language != null && language.isNotEmpty ? language : null,
  );

  await context.push('/reader/$textId', extra: navigationContext);
}

/// Completion is keyed by the chant ID we POST (`item.id`), but the
/// `complete/today` payload has been seen carrying text IDs, so both are
/// matched.
bool _isItemCompleted(
  MyRecitationCollectionCompletionState completionState,
  MyRecitationCollectionItemModel item,
) {
  return completionState.isCompleted(item.id) ||
      completionState.isCompleted(item.textId);
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onMenuTap});

  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppAssets.arrowLeft),
            onPressed: () {
              if (context.canPop()) context.pop();
            },
          ),
          const Spacer(),
          if (onMenuTap != null)
            IconButton(
              icon: const Icon(AppAssets.dotsThreeVerticalBold),
              onPressed: onMenuTap,
            ),
        ],
      ),
    );
  }
}

/// The square cover: the image, or a book on grey without one. With
/// [onChange] a camera badge sits on its corner.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.imageUrl,
    required this.localFile,
    required this.isDark,
    this.onChange,
  });

  final String? imageUrl;
  final File? localFile;
  final bool isDark;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final Widget image;
    if (localFile != null) {
      image = Image.file(
        localFile!,
        width: _kCoverSize,
        height: _kCoverSize,
        fit: BoxFit.cover,
        cacheWidth:
            (_kCoverSize * MediaQuery.devicePixelRatioOf(context)).round(),
      );
    } else if (url.isNotEmpty) {
      image = CachedNetworkImageWidget(
        imageUrl: url,
        fallbackAsset: AppAssets.myCollectionDefault,
        width: _kCoverSize,
        height: _kCoverSize,
        fit: BoxFit.cover,
      );
    } else {
      image = Container(
        width: _kCoverSize,
        height: _kCoverSize,
        color: ChantBookColors.coverPlaceholder(isDark),
        alignment: Alignment.center,
        child: Icon(
          AppAssets.bookOpen,
          size: 56,
          color: ChantBookColors.secondaryText(isDark),
        ),
      );
    }

    return SizedBox.square(
      dimension: _kCoverSize,
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: image),
          if (onChange != null)
            Positioned(
              right: 10,
              bottom: 10,
              child: Semantics(
                button: true,
                label: context.l10n.chant_book_change_cover,
                child: Material(
                  color: AppColors.surfaceWhite,
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onChange,
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        AppAssets.camera,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.isDark,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ChantBookColors.tint(isDark),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 76),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.isDark, this.onPressed});

  final bool isDark;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(AppAssets.caretRight2, size: 16),
        label: Text(
          context.l10n.chant_book_start,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              isDark ? AppColors.surfaceWhite : AppColors.textPrimary,
          foregroundColor:
              isDark ? AppColors.textPrimary : AppColors.surfaceWhite,
          disabledBackgroundColor:
              isDark ? AppColors.grey800 : AppColors.grey300,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// One chant of the book: on the user's own book a drag handle and a ⋮
/// frame the title, its line under it, and the open arrow.
class _ChantRow extends StatelessWidget {
  const _ChantRow({
    super.key,
    required this.item,
    required this.index,
    required this.isDark,
    required this.isOwn,
    required this.onOpen,
    required this.onMore,
  });

  final MyRecitationCollectionItemModel item;
  final int index;
  final bool isDark;
  final bool isOwn;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = ChantBookColors.secondaryText(isDark);
    final language = item.language?.trim() ?? '';
    final firstAudio = item.audio.isEmpty ? null : item.audio.first;
    final listenLine =
        firstAudio == null
            ? l10n.chant_book_read_along
            : (firstAudio.reciterName ?? firstAudio.title).trim();
    final subtitle = [
      if (language.isNotEmpty) getLanguageName(language, context),
      if (listenLine.isNotEmpty) listenLine,
    ].join(' · ');

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isOwn ? 8 : _kPagePadding,
          10,
          isOwn ? 8 : _kPagePadding,
          10,
        ),
        child: Row(
          children: [
            if (isOwn)
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: l10n.chant_book_reorder_chant,
                  child: SizedBox(
                    width: 32,
                    height: 44,
                    child: Icon(
                      AppAssets.dotsSixVertical,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChantContentText(
                    _titleOf(item),
                    language: item.language,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ChantCircleButton(
              icon: AppAssets.caretRight,
              iconSize: 16,
              semanticLabel: l10n.chants_open_chant,
              onPressed: onOpen,
            ),
            if (isOwn)
              IconButton(
                tooltip: l10n.chant_book_chant_options,
                icon: const Icon(AppAssets.dotsThreeVerticalBold, size: 22),
                onPressed: onMore,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddChantsRow extends StatelessWidget {
  const _AddChantsRow({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_kPagePadding, 12, _kPagePadding, 0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: ChantBookColors.tint(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(AppAssets.plus, size: 22),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                height: 60,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.grey800 : AppColors.grey100,
                    ),
                  ),
                ),
                child: Text(
                  context.l10n.my_recitation_collection_add_chants,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
