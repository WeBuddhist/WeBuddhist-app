import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/widgets/error_state_widget.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/home/domain/entities/series.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_explore_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_spaces_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/plans_search_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_load_notice.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_plan_card.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_plan_list_tile.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_space_cards.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_spaces_section.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/space_filter_pills.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

/// The Plans screen, opened by Home's Plans shortcut and by Practice →
/// Plans → See all.
///
/// Pills pick the plans: All is the catalog plus every space's plans, My
/// spaces the spaces the user joined, Other spaces the rest. Under All the
/// catalog's featured plans come first in a carousel.
class AllPlansScreen extends ConsumerStatefulWidget {
  const AllPlansScreen({super.key, this.initialFilter = SpaceFilter.all});

  /// The pill it opens on: My spaces from "From your spaces".
  final SpaceFilter initialFilter;

  @override
  ConsumerState<AllPlansScreen> createState() => _AllPlansScreenState();
}

class _AllPlansScreenState extends ConsumerState<AllPlansScreen> {
  late SpaceFilter _filter = widget.initialFilter;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openSeries(Series series) {
    context.pushNamed('home-series-detail', pathParameters: {'id': series.id});
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'plans-search'),
        builder: (_) => PlansSearchScreen(onTap: _openSeries),
      ),
    );
  }

  void _select(SpaceFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _refresh(SpaceFilter filter) async {
    await Future.wait([
      if (filter == SpaceFilter.all)
        ref
            .read(practiceExploreRepositoryProvider)
            .refreshSeries(ref.read(contentLanguageProvider)),
      if (filter != SpaceFilter.otherSpaces)
        ref.refresh(
          practiceSpaceFeedProvider((
            row: PracticeSpaceRow.plans,
            joined: true,
          )).future,
        ),
      if (filter != SpaceFilter.mySpaces)
        ref.refresh(
          practiceSpaceFeedProvider((
            row: PracticeSpaceRow.plans,
            joined: false,
          )).future,
        ),
    ]);
  }

  void _retrySpaces() {
    ref.invalidate(
      practiceSpaceFeedProvider((row: PracticeSpaceRow.plans, joined: true)),
    );
    ref.invalidate(
      practiceSpaceFeedProvider((row: PracticeSpaceRow.plans, joined: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isGuest = ref.watch(
      authProvider.select((auth) => !auth.isLoggedIn || auth.isGuest),
    );
    final filters = SpaceFilter.available(isGuest: isGuest);
    final filter = filters.contains(_filter) ? _filter : SpaceFilter.all;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(AppAssets.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.home_shortcut_plans,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.search_for_plans,
            onPressed: _openSearch,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpaceFilterPills(
            filters: filters,
            selected: filter,
            onSelected: _select,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(filter),
              child: _buildList(context, filter),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, SpaceFilter filter) {
    final l10n = context.l10n;
    final catalog =
        filter == SpaceFilter.all
            ? _read(ref.watch(practiceExploreSeriesProvider))
            : const _Loaded<List<Series>>.done(<Series>[]);
    final joined =
        filter != SpaceFilter.otherSpaces
            ? _read(
              ref.watch(
                practiceSpaceFeedProvider((
                  row: PracticeSpaceRow.plans,
                  joined: true,
                )),
              ),
            )
            : const _Loaded<List<GroupPractice>>.done(<GroupPractice>[]);
    final others =
        filter != SpaceFilter.mySpaces
            ? _read(
              ref.watch(
                practiceSpaceFeedProvider((
                  row: PracticeSpaceRow.plans,
                  joined: false,
                )),
              ),
            )
            : const _Loaded<List<GroupPractice>>.done(<GroupPractice>[]);

    final series = catalog.value ?? const <Series>[];
    final featured = series.where((s) => s.featured).toList();
    final catalogRows = series.where((s) => !s.featured).toList();
    final spaceRows = [...?joined.value, ...?others.value];
    final rowCount = catalogRows.length + spaceRows.length;

    final isLoading = catalog.isLoading || joined.isLoading || others.isLoading;
    final spacesFailed = joined.failure != null || others.failure != null;
    final failure = catalog.failure ?? joined.failure ?? others.failure;

    if (featured.isEmpty && rowCount == 0) {
      if (isLoading) return const Center(child: CircularProgressIndicator());
      if (failure != null) {
        return _fill(
          ErrorStateWidget(
            error: failure.message,
            onRetry: () {
              ref.invalidate(practiceExploreSeriesProvider);
              _retrySpaces();
            },
          ),
        );
      }
      return _fill(Text(l10n.no_plans_found, textAlign: TextAlign.center));
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Some space plans could not be read: said above what did load.
        if (spacesFailed)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ChantLoadNotice(
                message: l10n.unableToLoad,
                onRetry: _retrySpaces,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        if (featured.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _Heading(title: l10n.creator_featured_plan),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: practicePlanRailHeight(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder:
                    (context, index) => Align(
                      alignment: Alignment.topCenter,
                      child: PracticePlanCard(
                        series: featured[index],
                        onTap: () => _openSeries(featured[index]),
                      ),
                    ),
              ),
            ),
          ),
          if (rowCount > 0)
            SliverToBoxAdapter(
              child: _Heading(title: l10n.home_shortcut_plans),
            ),
        ],
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, featured.isEmpty ? 8 : 0, 16, 0),
          sliver: SliverList.separated(
            itemCount: rowCount,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index < catalogRows.length) {
                final s = catalogRows[index];
                return PracticePlanListTile(
                  series: s,
                  onTap: () => _openSeries(s),
                );
              }
              return PracticeSpacePlanListTile(
                practice: spaceRows[index - catalogRows.length],
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// Centers [child] in a scroll view, so pull-to-refresh still works.
  Widget _fill(Widget child) {
    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Padding(padding: const EdgeInsets.all(24), child: child),
              ),
            ),
          ),
    );
  }
}

/// One source of the list: its loaded value, its failure, or still loading.
class _Loaded<T> {
  const _Loaded({this.value, this.failure, this.isLoading = false});
  const _Loaded.done(T this.value) : failure = null, isLoading = false;

  final T? value;
  final Failure? failure;
  final bool isLoading;
}

_Loaded<T> _read<T>(AsyncValue<Either<Failure, T>> async) {
  final result = async.valueOrNull;
  if (result == null) {
    return _Loaded(
      isLoading: !async.hasError,
      failure: async.hasError ? UnknownFailure(async.error.toString()) : null,
    );
  }
  return result.fold(
    (failure) => _Loaded(failure: failure),
    (value) => _Loaded(value: value),
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        strutStyle: context.tibetanStrutStyle(18),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}
