import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pecha/features/home/presentation/providers/use_case_providers.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/services/service_providers.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/state_providers.dart';
import 'package:flutter_pecha/features/auth/presentation/widgets/login_drawer.dart';
import 'package:flutter_pecha/features/home/presentation/providers/routine_info_provider.dart';
import 'package:flutter_pecha/features/home/presentation/providers/streak_provider.dart';
import 'package:flutter_pecha/features/home/presentation/providers/verse_of_day_engagement_providers.dart';
import 'package:flutter_pecha/features/home/presentation/providers/verse_of_day_provider.dart';
import 'package:flutter_pecha/features/home/presentation/home_screen_constants.dart';
import 'package:flutter_pecha/features/home/presentation/utils/home_analytics.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/home_header.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/home_feed_sliver.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/home_shortcuts_row.dart';
import 'package:flutter_pecha/features/home/presentation/providers/home_feed_provider.dart';
import 'package:flutter_pecha/features/home/presentation/providers/home_poems_preview_provider.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/my_practices_stats_card.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/my_practices_stats_card_skeleton.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_of_day_carousel.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_of_day_skeleton.dart';
import 'package:flutter_pecha/features/mala/presentation/utils/mala_analytics.dart';
import 'package:flutter_pecha/features/notifications/application/notification_sync_engine.dart';
import 'package:flutter_pecha/features/onboarding/presentation/providers/user_tradition_codes_provider.dart';
import 'package:flutter_pecha/features/plans/data/utils/plan_utils.dart';
import 'package:flutter_pecha/features/plans/presentation/providers/user_plans_provider.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/routine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('HomeScreen');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasRequestedPermissions = false;

  // For proper keyboard dismissal with SearchAnchor
  final FocusScopeNode _searchFocusScopeNode = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    _trackHomeViewed();
    // Request notification permissions when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermissionsIfNeeded();
    });
  }

  /// Once per mount of the Home tab, with what the providers already hold.
  void _trackHomeViewed() {
    final streak = ref.read(streakFutureProvider).valueOrNull;
    ref
        .read(homeAnalyticsProvider)
        .homeViewed(
          hasRoutine: ref.read(routineProvider).hasItems,
          streakCurrent: streak?.fold<int?>((_) => null, (days) => days),
          isGuest: ref.read(authProvider).isGuest,
        );
  }

  @override
  void dispose() {
    _searchFocusScopeNode.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermissionsIfNeeded() async {
    _log.info(
      '[HOME-SCREEN] _requestNotificationPermissionsIfNeeded ENTER '
      'hasRequested=$_hasRequestedPermissions',
    );
    if (_hasRequestedPermissions) return;
    _hasRequestedPermissions = true;

    // Capture the root ProviderContainer BEFORE any await. The OS permission
    // dialog backgrounds the app and may dispose this State by the time we
    // resume — `ref` becomes unusable but the container lives for the whole
    // app, so post-permission scheduling still fires either way.
    final container = ProviderScope.containerOf(context, listen: false);

    final notificationService = container.read(notificationServiceProvider);
    if (notificationService == null) {
      _log.warning(
        '[HOME-SCREEN] NotificationService not initialized, skipping permission request',
      );
      if (mounted) _navigateToPendingPlanIfNeeded();
      return;
    }

    try {
      // Check if permissions are already granted
      final alreadyEnabled =
          await notificationService.areNotificationsEnabled();
      _log.info('[HOME-SCREEN] alreadyEnabled=$alreadyEnabled');
      if (!alreadyEnabled) {
        _log.info('[HOME-SCREEN] requesting notification permissions...');
        final granted = await notificationService.requestPermission();
        _log.info('[HOME-SCREEN] permission request result granted=$granted');
      }
    } catch (e) {
      _log.warning(
        '[HOME-SCREEN] error requesting notification permissions: $e',
      );
    }

    // Permission flow has run — fire any pending special-plan Day 1
    // notifications now (e.g. user just enrolled in ITCC during onboarding
    // after 09:00). Without permission, `_plugin.show()` silently no-ops, so
    // this MUST run after the permission request above.
    await _firePendingSpecialPlanDay1IfNeeded(container);

    if (!mounted) return;

    // After the permission flow (dialog shown or already granted), check
    // whether onboarding left a plan waiting to be opened in Practice.
    _navigateToPendingPlanIfNeeded();
  }

  Future<void> _firePendingSpecialPlanDay1IfNeeded(
    ProviderContainer container,
  ) async {
    // Use [container], NOT `this.ref` — see the comment in the caller.
    // Invalidate first — the provider may have been evaluated pre-login
    // (no auth header) and cached a Forbidden failure. We need a fresh read.
    _log.info('invalidating userPlansFutureProvider for fresh fetch');
    container.invalidate(userPlansFutureProvider);

    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      _log.info('fetch attempt $attempt/$maxAttempts');
      try {
        final userPlansAsync = await container.read(
          userPlansFutureProvider.future,
        );
        final isFailure = userPlansAsync.isLeft();
        _log.info('attempt $attempt resolved isFailure=$isFailure');
        if (isFailure && attempt < maxAttempts) {
          _log.warning(
            'attempt $attempt failed — invalidating and retrying: '
            '${userPlansAsync.fold((f) => f, (_) => "")}',
          );
          container.invalidate(userPlansFutureProvider);
          await Future.delayed(const Duration(milliseconds: 400));
          continue;
        }
        await userPlansAsync.fold(
          (failure) async {
            _log.warning(
              'giving up after $attempt attempts — fetch failed: $failure',
            );
          },
          (response) async {
            _log.info(
              'user plans loaded count=${response.userPlans.length} '
              'on attempt=$attempt — triggering engine sync (appLaunch)',
            );
            // Permission may have just been granted; trigger a sync so
            // catch-up immediates fire now that `plugin.show()` works.
            await container
                .read(notificationSyncEngineProvider)
                .sync(trigger: SyncTrigger.appLaunch);
          },
        );
        break;
      } catch (e, st) {
        _log.warning('attempt $attempt threw: $e\n$st');
        if (attempt < maxAttempts) {
          container.invalidate(userPlansFutureProvider);
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    _log.info('_firePendingSpecialPlanDay1IfNeeded EXIT');
  }

  /// Consumes [pendingOnboardingPlanProvider] and navigates to the Practice
  /// tab + plan detail screen. Called once, right after notification setup.
  void _navigateToPendingPlanIfNeeded() {
    if (!mounted) return;
    final plan = ref.read(pendingOnboardingPlanProvider);
    if (plan == null) return;

    // Clear immediately so back-navigation never re-triggers this.
    ref.read(pendingOnboardingPlanProvider.notifier).state = null;

    // Push plan details FIRST while HomeScreen is still mounted.
    // Switching the tab index BEFORE the push would unmount HomeScreen,
    // making the subsequent context.push a no-op.
    final anchor = plan.effectiveStartDate;
    final selectedDay = PlanUtils.dayNumberFor(
      anchor,
      DateTime.now(),
      plan.totalDays,
    ).clamp(1, plan.totalDays);
    _log.info(
      '[ENROLL-NAV] onboarding open ${plan.id} '
      'anchor=${anchor.toIso8601String()} '
      'startDate=${plan.startDate?.toIso8601String()} '
      'startedAt=${plan.startedAt.toIso8601String()} '
      'selectedDay=$selectedDay/${plan.totalDays}',
    );
    context.push(
      '/practice/details',
      extra: {'plan': plan, 'selectedDay': selectedDay, 'startDate': anchor},
    );

    // Switch bottom-nav to Practice so popping back from plan details
    // lands on the Practice tab rather than Home.
    ref.read(mainNavigationIndexProvider.notifier).state =
        MainTab.practice.index;
  }

  /// Pull-to-refresh: awaits the server fetches so the spinner stays until
  /// data lands; each store write reaches its section through its stream.
  Future<void> _onRefresh() async {
    _refreshVerseOfDayEngagement();
    final language = ref.read(contentLanguageProvider);
    await Future.wait<Object?>([
      // A fresh mix: the feed drops its cursor.
      ref.read(homeFeedProvider.notifier).refresh(),
      ref.read(homePoemsPreviewSourceProvider).refresh(),
      // The verse-of-the-day week; also stores today's verse on its own.
      // A failed tradition lookup is retried first so the verse isn't stuck
      // on All traditions.
      () async {
        await ref.read(userTraditionCodesProvider.notifier).retryIfFailed();
        await ref
            .read(verseOfDayDomainRepositoryProvider)
            .refreshRecentVerses(
              language: language,
              tradition: ref.read(verseOfDayTraditionProvider),
            );
      }(),
      ref
          .read(todayEventsDomainRepositoryProvider)
          .refreshTodayEvents(language: language),
      ref.read(routineInfoDomainRepositoryProvider).refreshRoutineInfo(),
      ref.read(streakDomainRepositoryProvider).refreshStreak(),
    ]);
  }

  /// Opens a login-only feature shortcut (Mala, Timer). Guests are prompted to
  /// sign in via the login drawer instead of navigating, since these features
  /// need an authenticated account to persist progress.
  /// [feature] names the shortcut, for `home_card_tapped` and, for guests,
  /// `login_prompt_shown`.
  void _openGatedFeature(
    String route, {
    required String feature,
    Object? extra,
  }) {
    ref
        .read(homeAnalyticsProvider)
        .cardTapped(section: HomeSection.shortcuts, targetId: feature);
    if (ref.read(authProvider).isGuest) {
      LoginDrawer.show(context, ref, feature: feature);
      return;
    }
    context.push(route, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(userProvider).user;
    final firstName = user?.visibleNameOrNull ?? user?.username;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: HomeTabAppBar(
        toolbarHeight: HomeTabAppBar.toolbarHeightFor(
          context: context,
          firstName: firstName,
        ),
        firstName: firstName,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [const HomeEventBanner(), _buildBody(context, l10n)],
      ),
    );
  }

  /// Always shown to members, 0 included; a failed read leaves the count
  /// out. Guests have no practices to count.
  Widget _buildMyPracticesSection() {
    final isGuest = ref.watch(
      authProvider.select((auth) => !auth.isLoggedIn || auth.isGuest),
    );
    if (isGuest) return const SizedBox.shrink();

    final routineInfoAsync = ref.watch(routineInfoFutureProvider);
    if (routineInfoAsync.isLoading && !routineInfoAsync.hasValue) {
      return const MyPracticesStatsCardSkeleton();
    }
    final count = routineInfoAsync.valueOrNull?.fold(
      (_) => null,
      (info) => info.totalCount,
    );
    return MyPracticesStatsCard(
      count: count,
      onTap: () {
        ref.read(homeAnalyticsProvider).cardTapped(section: HomeSection.stats);
        context.pushNamed('my-practices');
      },
    );
  }

  /// Likes and comments live in their own providers, which stay alive with
  /// the card, so invalidating the verse alone leaves their counts stale.
  ///
  /// Covers every day of the week that has a card on screen; a day whose
  /// providers don't exist loads fresh when its card first shows.
  void _refreshVerseOfDayEngagement() {
    final weekIds =
        ref
            .read(recentVersesOfDayProvider)
            .valueOrNull
            ?.fold((_) => null, (verses) => verses.map((v) => v.id)) ??
        const <String>[];

    for (final verseId in weekIds) {
      if (verseId.isEmpty) continue;
      if (ref.exists(verseOfDayLikesProvider(verseId))) {
        ref.read(verseOfDayLikesProvider(verseId).notifier).load();
      }
      if (ref.exists(verseOfDayCommentsProvider(verseId))) {
        ref.read(verseOfDayCommentsProvider(verseId).notifier).loadInitial();
      }
    }
  }

  Widget _buildVerseOfDaySection() {
    final versesAsync = ref.watch(recentVersesOfDayProvider);

    return versesAsync.when(
      data: (versesEither) {
        return versesEither.fold(
          (_) => const SizedBox.shrink(),
          (verses) => VerseOfDayCarousel(verses: verses),
        );
      },
      loading: () => const VerseOfDaySkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations localizations) {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification:
              (notification) => HomeFeedSliver.onScroll(ref, notification),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVerseOfDaySection(),
                    const SizedBox(height: HomeScreenConstants.cardSpacing),
                    HomeShortcutsRow(
                      onTimerTap:
                          () => _openGatedFeature(
                            '/home/timers',
                            feature: 'timer',
                          ),
                      onMalaTap:
                          () => _openGatedFeature(
                            '/mala',
                            feature: 'mala',
                            extra: {'source': MalaOpenSource.home},
                          ),
                    ),
                    const SizedBox(height: HomeScreenConstants.cardSpacing),
                    _buildMyPracticesSection(),
                    const SizedBox(height: HomeScreenConstants.cardSpacing),
                  ],
                ),
              ),
              const HomeFeedSliver(),
              // Room below the last row, clear of the bottom navigation.
              const SliverToBoxAdapter(
                child: SizedBox(height: HomeScreenConstants.cardSpacing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
