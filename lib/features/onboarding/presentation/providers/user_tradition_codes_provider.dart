import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_key.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_providers.dart';
import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_store.dart';
import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/onboarding/data/datasource/onboarding_remote_datasource.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/onboarding_datasource_providers.dart';
import 'package:flutter_pecha/features/onboarding/presentation/utils/tradition_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('UserTraditionCodes');

/// Sorted tradition codes (`pali`, `chinese`, `tibetan`) the signed-in user
/// follows. Empty for guests, signed-out users, and a failed lookup with
/// nothing stored.
///
/// Feeds the backend narrows by the caller's saved traditions (poems) key
/// their stored pages by these codes and re-fetch when they change.
///
/// Same lifecycle as `traditionTagFilterProvider`: loading only while auth is
/// unknown or on a user's first resolution; after that the stored codes are
/// the first value and the server's replace them if they changed. Kept alive
/// so the lookup runs once per session. Invalidate it after the user's
/// traditions change.
///
/// A failed lookup is retried when connectivity returns and from
/// [UserTraditionCodesNotifier.retryIfFailed] (Home refresh), so a lookup
/// that failed with nothing stored does not leave the user on the All
/// traditions verse for the rest of the session.
///
/// Each successful lookup also tells analytics the codes when they differ
/// from what this device last reported for the account, which keeps the
/// person's `traditions` current after onboarding and profile edits.
final userTraditionCodesProvider =
    AsyncNotifierProvider<UserTraditionCodesNotifier, List<String>>(
      UserTraditionCodesNotifier.new,
    );

class UserTraditionCodesNotifier extends AsyncNotifier<List<String>> {
  // Bumped per build so a resolution finishing after a rebuild is dropped.
  int _epoch = 0;

  // Whether this build's latest lookup failed; only then is a retry worth it.
  bool _lookupFailed = false;
  Future<void>? _retry;
  OnboardingRemoteDatasource? _datasource;
  ScreenCacheStore? _store;
  TraditionAnalytics? _analytics;

  @override
  FutureOr<List<String>> build() {
    final epoch = ++_epoch;
    _lookupFailed = false;
    _retry = null;
    _datasource = null;
    _store = null;
    _analytics = null;
    final (isAuthLoading, isLoggedIn, isGuest) = ref.watch(
      authProvider.select(
        (auth) => (auth.isLoading, auth.isLoggedIn, auth.isGuest),
      ),
    );
    if (isAuthLoading) return Completer<List<String>>().future;
    if (!isLoggedIn || isGuest) return const [];

    final store = ref.watch(screenCacheStoreProvider);
    final datasource = ref.watch(onboardingRemoteDatasourceProvider);
    _store = store;
    _datasource = datasource;
    _analytics = ref.watch(traditionAnalyticsProvider);
    final subscription = ref
        .watch(networkInfoProvider)
        .onConnectivityChanged
        .listen((isOnline) {
          if (isOnline) unawaited(retryIfFailed());
        });
    ref.onDispose(subscription.cancel);

    final key = storageKey(store);
    final stored = _readStored(store, key);
    final fresh = _lookup(
      datasource,
      store,
      key,
      epoch,
    ).then((codes) => codes ?? stored ?? const <String>[]);
    if (stored == null) return fresh;

    fresh.then((codes) {
      if (epoch == _epoch && !listEquals(codes, stored)) {
        state = AsyncData(codes);
      }
    });
    return stored;
  }

  /// Re-runs the lookup if the latest one failed, keeping the current codes
  /// until it succeeds. Completes once the codes are settled, so callers can
  /// read the user's tradition right after. Never throws.
  Future<void> retryIfFailed() {
    if (!_lookupFailed) return Future.value();
    return _retry ??= () async {
      final epoch = _epoch;
      final datasource = _datasource;
      final store = _store;
      if (datasource == null || store == null) return;
      // Let a first resolution still in flight settle before comparing.
      await future;
      final codes = await _lookup(datasource, store, storageKey(store), epoch);
      if (epoch != _epoch) return;
      _retry = null;
      if (codes != null && !listEquals(codes, state.valueOrNull)) {
        state = AsyncData(codes);
      }
    }();
  }

  static String storageKey(ScreenCacheStore store) => ScreenCacheKey.user(
    'tradition_codes',
    userId: store.currentUserIdSync,
    language: 'all',
  );

  /// Where the codes last reported to analytics for this account are kept.
  static String reportedKey(ScreenCacheStore store) => ScreenCacheKey.user(
    'tradition_codes_reported',
    userId: store.currentUserIdSync,
    language: 'all',
  );

  static List<String>? _readStored(ScreenCacheStore store, String key) {
    final json = store.read(key);
    if (json == null) return null;
    try {
      return (jsonDecode(json) as List<dynamic>).cast<String>();
    } catch (e) {
      _logger.warning('Discarding unreadable stored tradition codes', e);
      return null;
    }
  }

  /// The user's codes, or null when the lookup failed (recorded for
  /// [retryIfFailed] if [epoch] is still current). Never throws.
  Future<List<String>?> _lookup(
    OnboardingRemoteDatasource datasource,
    ScreenCacheStore store,
    String key,
    int epoch,
  ) async {
    try {
      // Codes don't depend on the language; names aren't used here.
      final selected = await datasource.fetchUserTraditions(language: 'en');
      final codes =
          selected.map((t) => t.traditionCode).toSet().toList()..sort();
      // A lookup from before a rebuild (e.g. a tradition edit) may finish
      // after the newer one; saving it would overwrite the newer codes.
      if (epoch != _epoch) return codes;
      await store.save(key, jsonEncode(codes));
      _lookupFailed = false;
      unawaited(_reportIfChanged(store, codes, epoch));
      return codes;
    } catch (e, stackTrace) {
      _logger.error('Resolving tradition codes failed', e, stackTrace);
      if (epoch == _epoch) _lookupFailed = true;
      return null;
    }
  }

  /// Tells analytics the account's codes when they differ from the last ones
  /// this device reported for it, so the person's profile is updated on a
  /// real change and not on every launch. Codes that could not be reported
  /// are not noted, and go out in a later session. Never throws.
  Future<void> _reportIfChanged(
    ScreenCacheStore store,
    List<String> codes,
    int epoch,
  ) async {
    final analytics = _analytics;
    // A rebuild since the lookup (sign-out, another account) owns the report.
    if (analytics == null || epoch != _epoch) return;
    try {
      final key = reportedKey(store);
      final json = jsonEncode(codes);
      final previous = store.read(key);
      if (previous == json) return;
      // Analytics is off in this build or did not start. Nothing is noted as
      // reported, so a later session with analytics on sends the codes.
      if (!analytics.canReport) return;
      // Nothing saved means nothing to compare with next time, and the same
      // report would go out every session.
      if (!await store.save(key, json)) return;
      // A sign-out or a tradition edit during the save: these codes belong
      // to an identity or a selection that is gone. Undo the note so the
      // lookup that replaced this one reports instead.
      if (epoch != _epoch) {
        await _forgetReport(store, key, written: json, previous: previous);
        return;
      }
      analytics.traditionsChanged(
        codes: codes,
        isFirstReport: previous == null,
      );
    } catch (e, stackTrace) {
      _logger.warning('Reporting tradition codes failed', e, stackTrace);
    }
  }

  /// Puts [previous] back as the last reported codes, unless a newer report
  /// has already replaced [written].
  static Future<void> _forgetReport(
    ScreenCacheStore store,
    String key, {
    required String written,
    required String? previous,
  }) async {
    if (store.read(key) != written) return;
    if (previous == null) {
      await store.remove(key);
    } else {
      await store.save(key, previous);
    }
  }
}
