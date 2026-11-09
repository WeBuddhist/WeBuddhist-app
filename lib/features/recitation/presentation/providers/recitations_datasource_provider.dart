import 'package:flutter_pecha/env.dart';
import 'package:flutter_pecha/features/library/data/adapters/library_recitations_remote_datasource.dart';
import 'package:flutter_pecha/features/library/presentation/providers/library_providers.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/tradition_tag_filter_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/my_recitation_collections_providers.dart';
import 'package:flutter_pecha/features/recitation/data/datasource/recitations_remote_datasource.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one recitations datasource: chant lists and search from the library,
/// collections from the main API. Rebuilt with the user's tradition tags, so
/// chant lists built from it are narrowed to their traditions; callers that
/// must not show an unfiltered list first wait on [traditionTagFilterProvider].
final recitationsRemoteDatasourceProvider =
    Provider<RecitationsRemoteDatasource>((ref) {
      return LibraryRecitationsRemoteDatasource(
        library: ref.watch(libraryRepositoryProvider),
        collections: ref.watch(myRecitationCollectionsRemoteDatasourceProvider),
        tagId: Env.libraryChantsTagId,
        traditionTagIds:
            ref.watch(traditionTagFilterProvider).valueOrNull ?? const [],
      );
    });
