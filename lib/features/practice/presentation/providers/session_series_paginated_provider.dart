import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/home/data/datasource/series_remote_datasource.dart';
import 'package:flutter_pecha/features/home/domain/entities/series.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionSeriesState {
  final List<Series> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;

  const SessionSeriesState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
  });

  SessionSeriesState copyWith({
    List<Series>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
  }) {
    return SessionSeriesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Paginated `GET /series` list for Add to session → Plans.
class SessionSeriesNotifier extends StateNotifier<SessionSeriesState> {
  SessionSeriesNotifier({
    required this.datasource,
    required this.languageCode,
    required this.includePrivateJoined,
  }) : super(const SessionSeriesState(isLoading: true)) {
    loadInitial();
  }

  final SeriesRemoteDatasource datasource;
  final String languageCode;
  final bool includePrivateJoined;

  static const int _pageSize = 20;

  SeriesQueryParams _params({required int skip}) {
    return SeriesQueryParams(
      language: languageCode,
      skip: skip,
      limit: _pageSize,
      includePrivateJoined: includePrivateJoined,
    );
  }

  Future<void> loadInitial() async {
    if (state.items.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final page = await datasource.fetchSeriesPage(params: _params(skip: 0));
      if (!mounted) return;
      state = SessionSeriesState(
        items: [
          for (final model in page.series)
            model.toEntity(language: languageCode),
        ],
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (!mounted) return;
      if (state.items.isEmpty) {
        state = state.copyWith(isLoading: false, error: e.toString());
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final page = await datasource.fetchSeriesPage(
        params: _params(skip: state.items.length),
      );
      if (!mounted) return;
      state = state.copyWith(
        items: [
          ...state.items,
          for (final model in page.series)
            model.toEntity(language: languageCode),
        ],
        isLoadingMore: false,
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadInitial();
}

final sessionSeriesPaginatedProvider = StateNotifierProvider.autoDispose<
  SessionSeriesNotifier,
  SessionSeriesState
>((ref) {
  final includePrivateJoined = ref.watch(
    authProvider.select((auth) => auth.isLoggedIn && !auth.isGuest),
  );
  return SessionSeriesNotifier(
    datasource: SeriesRemoteDatasource(dio: ref.watch(dioProvider)),
    languageCode: ref.watch(contentLanguageProvider),
    includePrivateJoined: includePrivateJoined,
  );
});
