import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/chants_page_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_explore_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_layout_memory.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_spaces_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/routine_api_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/practice_search_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_accumulations_section.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_chants_section.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_explore_skeleton.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_next_session_section.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_plans_section.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_section_container.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_shortcut_buttons.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_spaces_section.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/practice_start_routine_pill.dart';
import 'package:flutter_pecha/shared/widgets/main_tab_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Practice tab.
///
/// With a routine or joined spaces it is grouped: the next routine session,
/// Mala and Timer, "From your spaces", then "Discover more" (the catalog
/// and spaces the user has not joined). Without either it is just the
/// discover rows under Mala and Timer. With nothing in My practices yet
/// (or as a guest) the "Start a routine" pill takes the next session's
/// place.
class PracticeExploreScreen extends ConsumerStatefulWidget {
  const PracticeExploreScreen({super.key});

  @override
  ConsumerState<PracticeExploreScreen> createState() =>
      _PracticeExploreScreenState();
}

class _PracticeExploreScreenState extends ConsumerState<PracticeExploreScreen> {
  /// The layout this account had when the tab last settled, read once.
  late PracticeLayout? _lastLayout =
      ref.read(practiceLayoutMemoryProvider).read();

  /// Keeps [layout] for the next visit when it differs from the last one.
  void _remember(PracticeLayout layout) {
    if (layout == _lastLayout) return;
    _lastLayout = layout;
    final memory = ref.read(practiceLayoutMemoryProvider);
    Future.microtask(() => memory.save(layout));
  }

  Future<void> _refreshAll() async {
    final repo = ref.read(practiceExploreRepositoryProvider);
    final language = ref.read(contentLanguageProvider);
    final auth = ref.read(authProvider);
    ref.invalidate(practiceSpacePracticesProvider);
    ref.invalidate(spaceChantBooksProvider);
    await Future.wait([
      repo.refreshSeries(language),
      repo.refreshRecitations(language),
      if (auth.isLoggedIn && !auth.isGuest)
        ref
            .read(routineApiRepositoryProvider)
            .refreshUserRoutine(language: language),
    ]);
  }

  void _openBookmarks() {
    if (ref.read(authProvider).isGuest) {
      LoginDrawer.show(context, ref, feature: 'bookmarks');
      return;
    }
    context.pushNamed('bookmarks');
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'practice-search'),
        builder: (_) => const PracticeSearchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: MainTabAppBar(
        title: l10n.nav_practice,
        actions: [
          IconButton(
            tooltip: l10n.bookmarks,
            onPressed: _openBookmarks,
            icon: Icon(
              AppAssets.bookmarkSimple,
              size: 24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).searchFieldLabel,
            onPressed: _openSearch,
            icon: Icon(
              AppAssets.search,
              size: 24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            for (final child in _sections(context))
              SliverToBoxAdapter(child: child),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context) {
    final auth = ref.watch(authProvider);
    final routineAsync = ref.watch(userRoutineProvider);
    final routine = routineAsync.valueOrNull;
    final hasRoutine = routine != null && routine.hasItems;
    final hasSpaces = ref.watch(practiceHasJoinedSpaceContentProvider);

    // Until sign-in settles the routine and joined spaces answer "none",
    // then load again once it does: both count as still loading.
    final routinePending =
        auth.isLoading || practiceLayoutPending(routineAsync);
    final spacesPending =
        auth.isLoading || ref.watch(practiceJoinedSpaceContentLoadingProvider);

    if (!routinePending && !spacesPending) {
      // A failed read says nothing about what the account has: keep the
      // last layout for the next visit.
      final failed =
          routineAsync.hasError ||
          ref.watch(practiceJoinedSpaceContentFailedProvider);
      if (!failed) _remember((routine: hasRoutine, spaces: hasSpaces));
    } else if (!hasRoutine && !hasSpaces) {
      // The layout is not known yet. Open on the one this account had
      // last time, its missing parts held by skeletons; with none kept, a
      // page-wide skeleton, so the simple layout never flashes before the
      // grouped one.
      final last = _lastLayout;
      if (last == null) {
        return [
          PracticeExploreSkeleton(
            showNextSession:
                auth.isLoading || (auth.isLoggedIn && !auth.isGuest),
          ),
        ];
      }
      if (last.routine || last.spaces) {
        return _grouped(
          context,
          nextSession:
              last.routine && routinePending
                  ? const PracticeNextSessionSkeleton()
                  : last.routine
                  ? null
                  : const PracticeStartRoutinePill(),
          spacesLoading: last.spaces && spacesPending,
        );
      }
    }

    if (!hasRoutine && !hasSpaces) {
      return const [
        PracticeStartRoutinePill(),
        Padding(
          padding: EdgeInsets.only(top: 16),
          child: PracticeShortcutButtons(),
        ),
        PracticePlansSection(),
        PracticeChantsSection(),
        PracticeAccumulationsSection(),
      ];
    }

    return _grouped(
      context,
      nextSession:
          hasRoutine
              ? PracticeNextSessionSection(routine: routine)
              : routinePending && _lastLayout?.routine == true
              ? const PracticeNextSessionSkeleton()
              : const PracticeStartRoutinePill(),
      spacesLoading: spacesPending && _lastLayout?.spaces == true,
    );
  }

  /// The grouped layout: the next session (or its skeleton), Mala and
  /// Timer, "From your spaces", then "Discover more".
  List<Widget> _grouped(
    BuildContext context, {
    required Widget? nextSession,
    required bool spacesLoading,
  }) {
    return [
      if (nextSession != null) nextSession,
      Padding(
        padding: EdgeInsets.only(top: nextSession != null ? 16 : 8),
        child: const PracticeShortcutButtons(),
      ),
      PracticeSpacesSection(loading: spacesLoading),
      PracticeGroupHeading(title: context.l10n.practice_discover_more),
      const PracticePlansSection(isSubsection: true),
      const PracticeChantsSection(isSubsection: true),
      const PracticeAccumulationsSection(isSubsection: true),
    ];
  }
}
