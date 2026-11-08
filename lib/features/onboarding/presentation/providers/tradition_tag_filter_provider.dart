import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_key.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_store.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/onboarding/data/datasource/onboarding_remote_datasource.dart';
import 'package:flutter_pecha/features/onboarding/domain/tradition_tag_ids.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/onboarding_datasource_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('TraditionTagFilter');

/// Library tags for the signed-in user's traditions, used to narrow the
/// chant list. Empty for guests, for "show me everything", and whenever the
/// lookup fails, so the list falls back to every chant rather than an error.
///
/// Loading only while auth is unknown or, on a user's first resolution, while
/// the two tradition requests run; after that the stored result is the first
/// value and the server one replaces it if it changed. Kept alive so the
/// lookup runs once per session, not once per screen. Invalidate it after the
/// user's traditions change.
final traditionTagFilterProvider =
    AsyncNotifierProvider<TraditionTagFilterNotifier, List<String>>(
      TraditionTagFilterNotifier.new,
    );

class TraditionTagFilterNotifier extends AsyncNotifier<List<String>> {
  // Bumped per build so a resolution finishing after a rebuild is dropped.
  int _epoch = 0;

  @override
  FutureOr<List<String>> build() {
    final epoch = ++_epoch;
    final (isAuthLoading, isLoggedIn, isGuest) = ref.watch(
      authProvider.select(
        (auth) => (auth.isLoading, auth.isLoggedIn, auth.isGuest),
      ),
    );
    if (isAuthLoading) return Completer<List<String>>().future;
    if (!isLoggedIn || isGuest) return const [];

    final store = ref.watch(screenCacheStoreProvider);
    final datasource = ref.watch(onboardingRemoteDatasourceProvider);
    final key = storageKey(store);
    final stored = _readStored(store, key);
    final fresh = _resolve(datasource, store, key, fallback: stored);
    if (stored == null) return fresh;

    fresh.then((tags) {
      if (epoch == _epoch && !listEquals(tags, stored)) state = AsyncData(tags);
    });
    return stored;
  }

  static String storageKey(ScreenCacheStore store) => ScreenCacheKey.user(
    'tradition_tags',
    userId: store.currentUserIdSync,
    language: 'all',
  );

  static List<String>? _readStored(ScreenCacheStore store, String key) {
    final json = store.read(key);
    if (json == null) return null;
    try {
      return (jsonDecode(json) as List<dynamic>).cast<String>();
    } catch (e) {
      _logger.warning('Discarding unreadable stored tradition tags', e);
      return null;
    }
  }

  /// Never throws: a failed lookup keeps [fallback], or no filter.
  static Future<List<String>> _resolve(
    OnboardingRemoteDatasource datasource,
    ScreenCacheStore store,
    String key, {
    required List<String>? fallback,
  }) async {
    try {
      final (catalog, selected) =
          await (
            datasource.fetchTraditions(),
            datasource.fetchUserTraditions(language: 'en'),
          ).wait;
      final tags = resolveTraditionTagIds(
        catalog: catalog,
        selectedCodes: selected.map((t) => t.traditionCode).toSet(),
      );
      await store.save(key, jsonEncode(tags));
      return tags;
    } catch (e, stackTrace) {
      _logger.error('Resolving tradition tags failed', e, stackTrace);
      return fallback ?? const [];
    }
  }
}
