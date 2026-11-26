import 'dart:async';

import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_key.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_notifier.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_source.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/user_tradition_codes_provider.dart';
import 'package:flutter_pecha/features/poems/data/datasource/poems_remote_datasource.dart';
import 'package:flutter_pecha/features/poems/domain/entities/poem.dart';
import 'package:flutter_pecha/features/poems/presentation/providers/poems_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const homePoemsPreviewLimit = 3;

/// Stored-page key for the preview. The feed is the user's: All traditions
/// poems plus their traditions' poems, so it is keyed by user and codes.
String homePoemsPreviewKey({
  required String? userId,
  required String language,
  required List<String> traditionCodes,
}) => ScreenCacheKey.user(
  'home_poems',
  userId: userId,
  language: language,
  version: 2,
  params: [traditionCodes.isEmpty ? 'all' : traditionCodes.join('-')],
);

/// Shared by the preview and Home's pull-to-refresh (`refresh()`).
final homePoemsPreviewSourceProvider =
    Provider.autoDispose<ScreenCacheSource<List<Poem>>>((ref) {
      final language = ref.watch(contentLanguageProvider);
      final remote = ref.watch(poemsRemoteDatasourceProvider);
      final store = ref.watch(screenCacheStoreProvider);
      final traditionCodes =
          ref.watch(userTraditionCodesProvider).valueOrNull ?? const [];
      return ScreenCacheSource<List<Poem>>(
        store: store,
        key: homePoemsPreviewKey(
          userId: store.currentUserIdSync,
          language: language,
          traditionCodes: traditionCodes,
        ),
        // No `tradition` param: with the token the backend uses the caller's
        // saved traditions (all of them, not just one).
        fetchJson:
            () => remote.fetchPoemsJson(
              language: poemsApiLanguageCode(language),
              skip: 0,
              limit: homePoemsPreviewLimit,
            ),
        fromJson:
            (json) =>
                PoemsRemoteDatasource.parsePage(
                  json,
                  skip: 0,
                  limit: homePoemsPreviewLimit,
                ).poems.map((poem) => poem.toEntity()).toList(),
        failureMessage: 'Failed to load poems',
      );
    });


/// Poems are fully public, so this fetches for guests too. Stored page is the first state.
final homePoemsPreviewProvider = AsyncNotifierProvider.autoDispose<
  AutoDisposeScreenCacheNotifier<List<Poem>, List<Poem>>,
  List<Poem>
>(() {
  return AutoDisposeScreenCacheNotifier((ref, bind) {
    if (ref.watch(userTraditionCodesProvider).isLoading) {
      return Completer<List<Poem>>().future;
    }
    return bind.source(
      ref.watch(homePoemsPreviewSourceProvider),
      select: (result) => result.fold((_) => const <Poem>[], (poems) => poems),
    );
  });
});
