import 'dart:async';

import 'package:flutter_pecha/core/cache/screen_cache/screen_cache_notifier.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/home/domain/entities/verse_of_day.dart';
import 'package:flutter_pecha/features/home/domain/utils/verse_of_day_tradition.dart';
import 'package:flutter_pecha/features/home/presentation/providers/use_case_providers.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/user_tradition_codes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

/// The tradition whose Verse of the Day the user gets (by
/// [verseOfDayTraditionPriority]), or null for the All traditions verse.
/// Null while the user's traditions are still loading too; callers that must
/// not show the wrong tradition first check [userTraditionCodesProvider].
final verseOfDayTraditionProvider = Provider<String?>((ref) {
  final codes = ref.watch(userTraditionCodesProvider).valueOrNull;
  return verseOfDayTradition(codes ?? const []);
});

/// The verse-of-the-day week for the carousel, newest first, for the user's
/// tradition. The stored week is the first state; re-fetches when the app
/// language or the user's tradition changes. Pending until the user's
/// traditions are known: each tradition has its own stored week, and another
/// tradition's must not show first.
final recentVersesOfDayProvider = AsyncNotifierProvider<
  ScreenCacheNotifier<List<VerseOfDay>, Either<Failure, List<VerseOfDay>>>,
  Either<Failure, List<VerseOfDay>>
>(() {
  return ScreenCacheNotifier((ref, bind) {
    if (ref.watch(userTraditionCodesProvider).isLoading) {
      return Completer<Either<Failure, List<VerseOfDay>>>().future;
    }
    final language = ref.watch(contentLanguageProvider);
    final tradition = ref.watch(verseOfDayTraditionProvider);
    final repository = ref.watch(verseOfDayDomainRepositoryProvider);
    final stored = ref
        .watch(homeLocalDatasourceProvider)
        .readRecentVerses(language, tradition: tradition)
        ?.map((model) => model.toEntity())
        .toList();
    return bind.stream(
      stored == null ? null : Right(stored),
      repository.watchRecentVerses(language: language, tradition: tradition),
    );
  });
});
