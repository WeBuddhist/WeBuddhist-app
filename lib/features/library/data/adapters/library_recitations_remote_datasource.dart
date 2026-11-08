import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/library/data/models/library_text.dart';
import 'package:flutter_pecha/features/library/data/repositories/library_repository.dart';
import 'package:flutter_pecha/features/practice/data/datasource/my_recitation_collections_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/data/models/my_recitation_collection_models.dart';
import 'package:flutter_pecha/features/recitation/data/datasource/recitations_remote_datasource.dart';
import 'package:flutter_pecha/features/recitation/data/models/my_recitation_list_collection_model.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitations_page_response.dart';

/// Chant catalogue and search from the library API; the user's collections
/// and saved chants still come from the main API.
///
/// [traditionTagIds] narrows the catalogue to the user's traditions. The
/// library matches either all or any of the tags it is given, never "chants
/// and any of these", so one tradition is asked for as `chants,tradition`
/// (all), while two or more fetch chant pages and keep the texts tagged with
/// any of them here, reading up to [maxFilterPages] pages to fill one.
class LibraryRecitationsRemoteDatasource extends RecitationsRemoteDatasource {
  LibraryRecitationsRemoteDatasource({
    required LibraryRepository library,
    required MyRecitationCollectionsRemoteDatasource collections,
    required String? tagId,
    List<String> traditionTagIds = const [],
  }) : _library = library,
       _collections = collections,
       _tagId = tagId,
       _traditionTagIds = List.unmodifiable(traditionTagIds);

  final LibraryRepository _library;
  final MyRecitationCollectionsRemoteDatasource _collections;

  /// Null when the build has no chants tag configured.
  final String? _tagId;
  final List<String> _traditionTagIds;
  final _logger = AppLogger('LibraryRecitationsRemoteDatasource');

  static const int _defaultLimit = 20;
  static const int _maxLimit = 100;
  static const int _minTitleQueryLength = 2;
  static const int _collectionsPageSize = 20;
  static const int _maxCollectionPages = 50;

  /// Library pages read for one requested page when filtering here.
  static const int maxFilterPages = 5;

  @override
  List<String> get cacheKeyParams =>
      _traditionTagIds.isEmpty
          ? const []
          : ['tags-${_traditionTagIds.join('-')}'];

  /// Tags sent to the library: the chants tag, plus the tradition when a
  /// single one can be matched server-side.
  String _serverTagIds(String chantsTagId) =>
      _traditionTagIds.length == 1
          ? '$chantsTagId,${_traditionTagIds.single}'
          : chantsTagId;

  /// Tags matched on the client, or null when the server did the filtering.
  Set<String>? get _clientTagIds =>
      _traditionTagIds.length > 1 ? _traditionTagIds.toSet() : null;

  /// `search` becomes the library title filter; `total` is synthesized from
  /// `has_more` so [RecitationsPageResponse.hasMore] keeps working, and
  /// `nextSkip` is the raw library offset. Each chant's `textId` is its
  /// edition id, the id the rest of the app stores.
  @override
  Future<RecitationsPageResponse> fetchRecitationsPage({
    RecitationsQueryParams? queryParams,
  }) async {
    final params = queryParams ?? RecitationsQueryParams();
    final skip = params.skip ?? 0;
    final limit = (params.limit ?? _defaultLimit).clamp(1, _maxLimit);
    final search = params.search?.trim();
    // Collections come from another API: when they fail the chants still
    // list. Handling the error here also keeps it from going unobserved if
    // the chant request below throws first.
    final collectionsFuture =
        params.shouldIncludeCollections
            ? _loadAllCollections().catchError((Object error) {
              _logger.warning('Recitation collections failed', error);
              return const <MyRecitationListCollectionModel>[];
            })
            : Future.value(const <MyRecitationListCollectionModel>[]);

    List<LibraryText> texts = const [];
    var hasMore = false;
    var nextSkip = skip;
    final tooShort =
        search != null &&
        search.isNotEmpty &&
        search.length < _minTitleQueryLength;
    if (!tooShort) {
      final tagId = _tagId;
      if (tagId == null) {
        throw StateError('LIBRARY_CHANTS_TAG_ID is not configured');
      }
      final clientTagIds = _clientTagIds;
      final pages = clientTagIds == null ? 1 : maxFilterPages;
      final kept = <LibraryText>[];
      for (var i = 0; i < pages; i++) {
        final page = await _library.fetchChants(
          tagId: _serverTagIds(tagId),
          language: params.language,
          title: search,
          limit: limit,
          offset: nextSkip,
          noCache: params.noCache,
        );
        kept.addAll(
          clientTagIds == null
              ? page.items
              : page.items.where((t) => t.tagIds.any(clientTagIds.contains)),
        );
        // Every library text counts towards the next offset, filtered-out and
        // edition-less ones included, so pages never repeat.
        nextSkip += page.items.length;
        hasMore = page.hasMore && page.items.isNotEmpty;
        if (!hasMore || kept.length >= limit) break;
      }
      // A text without an edition has nothing to open, so it is not listed.
      texts = kept.where((t) => t.primaryEditionId != null).toList();
    }

    // No first-verse preview: it cost two more calls per chant.
    final recitations = [
      for (final text in texts)
        RecitationModel(
          textId: text.primaryEditionId!,
          title: text.displayTitle,
          language: text.language,
        ),
    ];
    return RecitationsPageResponse(
      recitations: recitations,
      collections: await collectionsFuture,
      skip: skip,
      limit: limit,
      total: nextSkip + (hasMore ? 1 : 0),
      nextSkip: nextSkip,
    );
  }

  /// Pages by the offset it asked for, not the one echoed back, and stops on
  /// a page with nothing new so a server ignoring `skip` cannot loop it.
  Future<List<MyRecitationListCollectionModel>> _loadAllCollections() async {
    final rows = <MyRecitationListCollectionModel>[];
    final seen = <String>{};
    var skip = 0;
    for (var i = 0; i < _maxCollectionPages; i++) {
      final page = await _collections.fetchCollections(
        skip: skip,
        limit: _collectionsPageSize,
      );
      final fresh = page.collections.where((c) => seen.add(c.id)).toList();
      rows.addAll(fresh.map(_toListModel));
      skip += page.collections.length;
      if (fresh.isEmpty || skip >= page.total) return rows;
    }
    _logger.warning(
      'Stopped listing collections after $_maxCollectionPages pages',
    );
    return rows;
  }

  static MyRecitationListCollectionModel _toListModel(
    MyRecitationCollectionModel collection,
  ) {
    return MyRecitationListCollectionModel(
      type: 'RECITATION_COLLECTION',
      name: collection.name,
      collectionId: collection.id,
      imageUrl: collection.imgUrl,
      itemCount: collection.itemCount,
    );
  }
}
