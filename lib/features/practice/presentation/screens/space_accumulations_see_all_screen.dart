import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/group_profile/domain/entities/group_practice.dart';
import 'package:flutter_pecha/features/practice/data/datasource/space_chant_books_remote_datasource.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_space_cards.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/space_filter_pills.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('SpaceAccumulationsSeeAll');

/// Space accumulations, the See all for the accumulation rails under
/// "From your spaces" and "Discover more": cards a page at a time, with All
/// / My spaces / Other spaces pills.
class SpaceAccumulationsSeeAllScreen extends ConsumerStatefulWidget {
  const SpaceAccumulationsSeeAllScreen({
    super.key,
    this.initialFilter = SpaceFilter.otherSpaces,
  });

  /// My spaces from "From your spaces", Other spaces from "Discover more".
  final SpaceFilter initialFilter;

  @override
  ConsumerState<SpaceAccumulationsSeeAllScreen> createState() =>
      _SpaceAccumulationsSeeAllScreenState();
}

class _SpaceAccumulationsSeeAllScreenState
    extends ConsumerState<SpaceAccumulationsSeeAllScreen> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  late SpaceFilter _filter = widget.initialFilter;
  final List<GroupPractice> _practices = [];
  bool _isLoading = false;
  bool _hasMore = true;

  /// Feed rows read so far, cards or not: the next page's offset. Rows
  /// without an accumulator are not shown, so this can pass the card count.
  int _rowsRead = 0;
  bool _failed = false;

  /// Bumped by a refresh or a pill change so a page still loading for the
  /// old list is dropped.
  int _epoch = 0;

  late final SpaceChantBooksRemoteDatasource _datasource =
      SpaceChantBooksRemoteDatasource(dio: ref.read(dioProvider));

  @override
  void initState() {
    super.initState();
    // A guest has no My spaces pill.
    if (_filter == SpaceFilter.mySpaces && _isGuest) {
      _filter = SpaceFilter.otherSpaces;
    }
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  bool get _isGuest {
    final auth = ref.read(authProvider);
    return !auth.isLoggedIn || auth.isGuest;
  }

  SpaceMembership get _membership => switch (_filter) {
    SpaceFilter.all => SpaceMembership.all,
    SpaceFilter.mySpaces => SpaceMembership.joined,
    SpaceFilter.otherSpaces => SpaceMembership.notJoined,
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // After a failed page only the Retry button and pull-to-refresh ask
    // again, or every scroll near the end would repeat the failing request.
    if (_failed) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    final epoch = _epoch;
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final page = await _datasource.fetchPractices(
        type: GroupPracticeType.accumulator,
        membership: _membership,
        language: ref.read(contentLanguageProvider),
        skip: _rowsRead,
        limit: _pageSize,
      );
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _rowsRead += page.practices.length;
        _practices.addAll(page.practices.where((p) => p.accumulator != null));
        _hasMore = page.hasMore && page.practices.isNotEmpty;
        _isLoading = false;
      });
      _continuePaging();
    } catch (e) {
      _logger.error('Failed to load space accumulations', e);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _isLoading = false;
        _failed = true;
      });
    }
  }

  /// Rows without a card can leave a page with nothing to show, or too
  /// little to scroll: the empty state has no scroll listener and a short
  /// list never fires one. Reads the next page once the frame has laid
  /// out, until the list can scroll or the feed ends.
  void _continuePaging() {
    if (!_hasMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading || !_hasMore) return;
      final canScroll =
          _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0;
      if (!canScroll) _loadMore();
    });
  }

  void _select(SpaceFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _refresh();
  }

  Future<void> _refresh() async {
    _epoch++;
    setState(() {
      _practices.clear();
      _rowsRead = 0;
      _hasMore = true;
      _isLoading = false;
      _failed = false;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppAssets.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.practice_space_accumulations,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpaceFilterPills(
            filters: SpaceFilter.available(
              isGuest: ref.watch(
                authProvider.select((auth) => !auth.isLoggedIn || auth.isGuest),
              ),
            ),
            selected: _filter,
            onSelected: _select,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_practices.isEmpty) {
      return LayoutBuilder(
        builder:
            (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: Center(child: _buildStatus(context)),
              ),
            ),
      );
    }

    final showFooter = _isLoading || _failed;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth - 32;
        return ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: _practices.length + (showFooter ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == _practices.length) {
              return Center(child: _buildStatus(context));
            }
            final practice = _practices[index];
            return PracticeSpaceAccumulatorCard(
              practice: practice,
              accumulator: practice.accumulator!,
              width: cardWidth,
              imageHeight: cardWidth * 9 / 16,
            );
          },
        );
      },
    );
  }

  /// Spinner, retry, or the empty message.
  Widget _buildStatus(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      );
    }
    if (_failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.something_went_wrong, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loadMore, child: Text(l10n.retry)),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        _filter == SpaceFilter.otherSpaces
            ? l10n.practice_no_space_accumulations
            : l10n.accumulations_no_found,
        textAlign: TextAlign.center,
      ),
    );
  }
}
