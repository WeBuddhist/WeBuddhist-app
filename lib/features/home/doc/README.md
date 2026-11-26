# Home Feature

> **LLM context doc** — read this before changing anything under `lib/features/home/`.

## Purpose

Home dashboard and **main navigation shell** (bottom nav: Home, Practice, Connect, Me). Aggregates verse of the day (with likes/comments/share), streak, today's events, shortcuts, My Practices, and an endless posts-and-events feed with poems and the share prompt placed inside it.

## User-facing functionality

Home tab (`HomeScreen`, top to bottom):

- **App bar** (`HomeTabAppBar` in `home_header.dart`) — greeting, then streak badge (`streakFutureProvider`), calendar button (`AppRoutes.calendar`) and chat button (`HomeChatButton`: members open `/chats`, with a red dot while any room is unread; guests get the sign-in drawer)
- **Today's events banner** (`HomeEventBanner` → `TodayEventBadge`) — from `GET /events/today`; re-evaluates "live" status every minute with a `Timer.periodic`; tapping opens the group event page via `openHomeLiveEvent` (`utils/home_live_event_navigation.dart`), which can deep-jump into the live recitation (`resolveHomeLiveEntry`)
- **Verse of the day** (`VerseOfDayCarousel` of `VerseOfDayCard`s, `recentVersesOfDayProvider`) — the last 7 days, today first; fixed-height image card with the verse, date pill, likes, likers sheet, threaded comments sheet (`verse_comments_sheet.dart`, `utils/verse_comment_threading.dart`), image/text share sheet
- **Shortcuts row** (`HomeShortcutsRow`) — Plans (`AllPlansScreen`: All / My spaces / Other spaces pills, catalog featured carousel, catalog + space plans via `practiceExploreSeriesProvider` and `practiceSpaceFeedProvider`), Chants (`AllRecitationsScreen`), Mala (`/mala`) and Timer (`/home/timers`); Mala/Timer are login-gated
- **My Practices** (`MyPracticesStatsCard`, `routineInfoFutureProvider`) — one pill, plans + chants as "N sessions" (`RoutineInfo.totalCount`); always shown to members ("Start a routine" at 0), hidden for guests → `my-practices` route
- **Feed** (`HomeFeedSliver`, `homeFeedProvider`) — posts and events only, drawn with the Connect cards (`ConnectFeedItemView`). Members read `GET /api/v2/feed` (cursor-paged, personalised; 403 without a token), guests `GET /api/v2/spaces/feed?include_unfollowed=true` (skip-paged). Pages load as Home scrolls (`HomeFeedSliver.onScroll`, plus `continuePaging` after each frame when a filtered page leaves the end in reach); after a failure only Retry asks again. The provider lives for the session, so a trip to `/chats` keeps the pages read
  - **Poems** (`PoemsSection`, `homePoemsPreviewProvider`, public) after the 4th card → `home-poems`
  - **Share-the-app prompt** (`HomeSharePrompt`) after the 8th card
  - A shorter feed gets both at its end once it has ended (`buildHomeFeedRows` in `utils/home_feed_rows.dart`)
- Pull-to-refresh reloads the feed with a fresh mix (drops the cursor), poems, verses, routine info and streak, and reloads verse engagement

Other screens: `SeriesDetailScreen` / `SeriesInfoScreen` (series browse + enrollment, incl. group enrollment), `PlanListScreen` (`home-plans`, plans by tag), `GroupEventsScreen`.

On first mount `HomeScreen` requests notification permission, triggers a notification-engine sync, then consumes `pendingOnboardingPlanProvider` to open the onboarding plan in Practice.

## Architecture

```
home/
├── home.dart           # partial barrel (mostly legacy tags/featured-day symbols)
├── data/               datasources, models, repositories, week_plan_*.dart (unused)
├── domain/             entities, all repository interfaces in home_repository.dart, usecases
└── presentation/       providers (one per concern), screens, utils, widgets, constants
```

## Key files

| Area | Files |
|------|-------|
| Nav shell | `presentation/screens/main_navigation_screen.dart` — `MainTab`, `mainNavigationIndexProvider`, `pendingOnboardingPlanProvider`, `HomeShellScaffold` (ShellRoute scaffold + Android back handling), `MainNavigationBottomBar` |
| Dashboard | `presentation/screens/home_screen.dart`, `presentation/widgets/home_header.dart`, `presentation/widgets/home_chat_button.dart` |
| Feed | `data/datasource/home_feed_remote_datasource.dart`, `data/models/home_feed_model.dart` (keeps posts/events, renames `space_*` keys to `group_*` for the Connect parser), `data/repositories/home_feed_repository_impl.dart`, `presentation/providers/home_feed_provider.dart`, `presentation/widgets/home_feed_sliver.dart`, `presentation/utils/home_feed_rows.dart` |
| DI hub | `presentation/providers/use_case_providers.dart` (datasources, repositories, use cases, `homeSyncBootstrapProvider`) |
| Local cache | `data/datasource/home_local_datasource.dart` (Hive box `home_local_data`, opened in `main.dart`) |
| Verse engagement | `presentation/providers/verse_of_day_engagement_providers.dart` |
| Series | `data/repositories/series_repository.dart`, `presentation/providers/series_enrollment_provider.dart` |
| Live event entry | `presentation/utils/home_live_event_navigation.dart`, `home_live_event_entry.dart` |
| Analytics | `presentation/utils/home_analytics.dart`, `series_analytics.dart` |

## State management

- `StreamProvider` backed by the local cache (names still end in `FutureProvider`): `recentVersesOfDayProvider`, `todayEventsFutureProvider`, `streakFutureProvider`, `routineInfoFutureProvider`, `seriesListFutureProvider`, `seriesByIdProvider`, `userSeriesEnrollmentsProvider`
- `FutureProvider.autoDispose`: `homePoemsPreviewProvider`
- `StateNotifierProvider` (not autoDispose; rebuilt on account or language change): `homeFeedProvider` — page one is stored per user, language and audience and shown at once, but paging waits for a fresh page one. Likes and comment counts changed elsewhere are patched in through `syncPostToListProviders` (connect); new or deleted posts show on pull-to-refresh
- `StateNotifierProvider.autoDispose.family`: `seriesEnrollmentProvider`, `verseOfDayLikesProvider`, `verseOfDayLikersProvider`, `verseOfDayCommentsProvider` (likes/comments re-created on login/logout)
- `StateProvider`: `mainNavigationIndexProvider`, `pendingOnboardingPlanProvider`
- User-scoped providers (streak, routine info) are invalidated on auth transitions by `userSessionBootstrapProvider` (auth feature)
- Day-scoped data (verse, today's events, streak) is **not** refreshed on day rollover/app resume — only on pull-to-refresh, language change or cold start

## Data sources

- **Remote:** `/verse-of-day/today` and `/verse-of-day?date=` for the six days before it (the week; no batch endpoint exists), both with `tradition=<code>` from `verseOfDayTraditionProvider`: the user's first tradition in Theravada (`pali`) > Vajrayana (`tibetan`) > Mahayana (`chinese`) order (`domain/utils/verse_of_day_tradition.dart`); left out for guests and users with none (All traditions verse). A day whose verses are for other traditions comes back null and is skipped (+ `/likes`, `/likes/users`, `/comments`, `/comments/{id}/likes`), `/events/today`, `/users/me/streak`, `/users/me/routine/info`, `/series`, `/series/featured`, `/series/{id}`, `/users/me/series` (GET enrollments, POST enroll with optional `group_id`), `/plans/featured/day`, `/plans/tags`
- **Local:** `HomeLocalDatasource` — keys per language (`verse_of_day:v2:<lang>:<tradition|all>`, `verse_of_day_date:v2:<lang>:<tradition|all>:<date>` per day, so each tradition keeps its own week and a tradition change re-fetches; with `fetched_at` — presigned image URLs die after 24 h, so a day older than 23 h is re-fetched — and `verse_of_day_recent:v2:` for the week's dates, `today_events:v2:`, `series_list:` …) or per user (`streak:`, `routine_info:`, `series_enrollments:`, pending enrollments). Repos yield cache first, refresh remote, then re-yield on `box.watch(key)`

- **Pending writes:** a personal series enrollment that fails offline (`NetworkException`) is queued locally and replayed by `flushPendingEnrollments()` (on enrollment refresh and on connectivity regain via `homeSyncBootstrapProvider`). Group enrollments never enter the queue (it doesn't keep `groupId`, so a replay would enroll personally); a failed group enrollment returns a `Left` and leaves any queued personal enrollment alone. A server rejection of a personal enrollment returns a `Left` and is undone locally, except a temporary error (5xx) on one that was already queued, which stays queued. The flush stops on network/auth/rate-limit errors, drops permanent refusals (400, 403, 404, 422; a 403 on a request sent without `Authorization` counts as an auth error and stays queued), and skips (keeps) other errors so they don't block later items

## Cross-feature dependencies

- **auth**, **calendar**, **group_profile** (events, group enrollment), **plans**, **practice** (routine, explore providers, all-plans/all-recitations screens), **poems**, **recitation** (live position peek), **notifications**, **connect**, **more** (Me tab)

## Notable patterns

- All repository interfaces live in one `domain/repositories/home_repository.dart`
- Stream + local cache: remote writes to Hive, UI watches streams
- Skeleton widgets paired with async cards
- Notification permission: capture `ProviderContainer` before await (the OS dialog can dispose the State)

## Legacy / unused code

Not referenced outside their own file (still exported from `home.dart`): `ActionOfTheDayCard`, `weekPlanProvider` + `week_plan_*.dart`, `CalendarBannerCard`, `TagSearchOverlay`, `StatButton`, `SeriesCard`, `featuredDayFutureProvider`, `tagsFutureProvider`. Featured series (`getFeaturedSeriesUseCaseProvider`, `SeriesRepository.getFeaturedSeries`) lost its only caller when the section left Home. Placeholder use cases in `home_usecases.dart` (DailyPrayer etc.) have no backend.

---

## How to make changes (LLM playbook)

### Principles

1. **Main nav lives here** — tab changes affect the whole app.
2. **Prefer stream + cache pattern** for new home feed data.
3. **Check barrel exports** — most providers aren't in `home.dart`; import directly.
4. Use `home_screen_constants.dart` for layout magic numbers.

### Do

- Add new dashboard sections as widget + provider + repository triplet
- Pair async cards with skeleton widgets
- Add new providers to `HomeScreen._onRefresh`
- Invalidate related providers on enrollment changes
- Use existing share sheet patterns for new shareable content

### Don't

- Don't block home render on optional cards — use AsyncValue / skeletons
- Don't move main navigation to another feature without team decision
- Don't implement placeholder use cases in `home_usecases.dart` without backend

### Common tasks

| Task | Where to start |
|------|----------------|
| New home card | widget + provider + datasource/repo, add to `_onRefresh` |
| Nav tab change | `main_navigation_screen.dart`, `MainTab`, routes in `core/config/router/app_router.dart` |
| Series enrollment | `series_enrollment_provider.dart`, `series_repository.dart`, group_profile `enrollSeriesThroughGroup` |
| Verse likes/comments | `verse_of_day_engagement_providers.dart`, `verse_of_day_repository.dart` |

### Testing

- Test offline stream replay from local datasource
- Test guest vs authenticated card visibility
- Test nav index persistence and Android back handling in `HomeShellScaffold`
