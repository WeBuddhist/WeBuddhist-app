# Mala (Prayer-Bead Counter)

A per-mantra recitation counter. The user taps an arc of prayer beads; each tap
is a monotonic +1 that is persisted locally and synced to the backend as an
**absolute lifetime total**. Counting never decreases.

## Architecture

Clean architecture, Riverpod for DI/state:

```
data/
  datasources/
    mala_remote_datasource.dart   REST calls (dio)
    mala_local_datasource.dart    Hive store (LocalMalaState), namespaced by user
    mala_appearance_remote_datasource.dart  v2 deity images, bead skins, user appearance
  models/
    accumulator_model.dart        JSON DTOs + toEntity()/toMalaCount()
    accumulator_group_model.dart  Group accumulator DTOs (ImageUrlModel → ResponsiveImage)
  repositories/
    mala_repository_impl.dart     maps exceptions → Failure (fpdart Either)
domain/
  entities/
    mantra.dart                   Mantra, MantraText, AccumulatorMetadata; kBeadsPerRound = 108
    mala_count.dart               MalaCount (total, totalCounted, accumulatorId, beadImageUrl)
    accumulator_group.dart        Joined group accumulator summary for a preset
    mala_accumulation_selection.dart  personal vs group selection value
    mala_image_option.dart        one Change image choice (id, image, isDefault)
    mala_skin.dart                one bead skin from GET /mala-skins
    mantra_appearance.dart        the user's deity image + bead skin for a mantra
  repositories/mala_repository.dart
  repositories/mala_appearance_repository.dart  appearance calls (deity images, skins, GET/PATCH)
  usecases/mala_usecases.dart     GetCatalogue / GetAccumulatorDetail / Create / Update /
                                  Delete (personal reset) / SubmitGroupCount / DeleteGroup
presentation/
  providers/
    mala_providers.dart           all DI providers + user-id resolution
    mala_counter_notifier.dart    per-mantra counter (seed + increment)
    mala_sync_manager.dart        app-scoped background sync
    mala_settings_provider.dart   sound / vibration / left-handed / play animation /
                                  mantra speed (persisted)
    mala_appearance_provider.dart per-mantra deity image + bead skin (server)
    accumulator_groups_provider.dart  joined groups + session seed fetch (autoDispose family)
    group_accumulation_counts_provider.dart  per-group session counts (Hive + sync)
    mala_accumulation_selection_provider.dart  personal vs group selection (SharedPreferences)
    accumulation_search_provider.dart preset search state (settings / add flows)
    accumulation_chant_counter.dart  counts reader chants into the selected target
  services/
    mala_sound_player.dart        bead-tap click (just_audio)
  utils/
    mala_analytics.dart           MalaAnalytics + MalaSessionTracker
    accumulation_sheet_display.dart  sheet section/total rules (events vs groups)
  screens/mala_screen.dart        screen layout (mantra card → counter → beads → group bar)
  screens/mala_settings_screen.dart  full-page Mala settings (⋮)
  widgets/
    mala_beads.dart               the tappable bead-arc CustomPainter
    mantra_switcher.dart          infinite looping carousel (swipe + ‹ › chevrons)
    mantra_marquee.dart           scrolling script / transliteration band
    mantra_animation_sheet.dart   play animation toggle + speed chips
    bead_style_sheet.dart         bead skin grid ("Use this style")
    change_image_sheet.dart       deity image grid ("Use", "Restore default")
    mala_sheet_frame.dart         shared sheet chrome, primary button, toast
    add_mala_rounds_button.dart   "+" beside the rounds count
    add_mala_rounds_dialog.dart   wheel picker for offline rounds
    group_accumulations_bar.dart  joined-group pill with overlapping avatars
    group_accumulations_sheet.dart  group accumulations bottom sheet
    mala_skeleton.dart            loading placeholder
```

## Backend API

Base dio (`dioProvider`). **All `/accumulators/*` routes require the bearer
token** — they are registered as protected in
`lib/core/config/protected_routes.dart` (`'/accumulators/'` catch-all). Without
it the user-scoped endpoints return **403**. The public preset catalogue is only
fetched by authenticated users, so the catch-all is safe.

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v2/accumulations?owner_type=platform` | Catalogue of preset mantras (paged, `language`). Same body as v1 `/accumulators/presets` plus each row's `last_used_at` (orders the carousel, see *Carousel order*). Sent with `no_cache` so it skips the 5-min HTTP cache and always returns the latest titles/images. Called as `ApiConfig.accumulationsV2Path` and listed in `ProtectedRoutes` on its own, since the `/accumulators/` catch-all doesn't cover it. |
| `GET` | `/accumulators/{parent_id}` | The user's detail for one preset. **404 ⇒ no accumulator yet ⇒ seed at 0.** |
| `GET` | `/accumulators/{accumulator_id}/groups` | Groups using this preset. Query `joined_only=true` returns only groups the user has joined. `{accumulator_id}` is the preset id (`Mantra.presetId`). Each row includes `user_total_count` — the user's **lifetime** total for that group (shown in the accumulations sheet). Sent with `no_cache`. |
| `POST` | `/accumulators/user` | Lazily create the user's accumulator (`{parent_id}`, starts at 0). |
| `PUT` | `/accumulators/user/{id}` | Push the absolute `current_count`. |
| `DELETE` | `/accumulators/user/{id}` | Soft-delete the active session accumulator (personal reset). |
| `GET` | `/group-accumulators/{group_accumulator_id}` | Group accumulator detail (group_profile). `user.total_count` is the user's **active session** count for bead tapping and sync. |
| `POST` | `/group-accumulators/{group_accumulator_id}` | Submit the user's absolute group session count (`{current_count}`). Path param is `group_accumulator_id` from the groups list, not `group_id`. |
| `DELETE` | `/group-accumulators/{group_accumulator_id}` | Soft-delete the user's active group session (group reset). Lifetime history on prior records is preserved server-side. |

`mala_image_url` appears at both the accumulator and mantra level; it drives the
bead artwork (see below).

## Counting model

Personal and group bead counting both sync **active session** absolutes
(`current_count` / `user.total_count`). Lifetime totals for group rows in the
accumulations sheet come from a separate field — see
[Group counting: session vs lifetime](#group-counting-session-vs-lifetime).

- **Monotonic absolute session totals.** The client always sends the absolute
  session total for the active accumulator, and both sides take `max()`.
  Re-sending the same total is a no-op, so retries are always safe and counts
  reconcile across devices.
- **Seed-before-send.** `MalaCounterNotifier.seed()` fetches the server total
  and `max()`-merges with the local total *before* taps are enabled
  (`isSeeding`), so a stale low value is never sent. The detail call is raced
  against a **3 s seed timeout**: on timeout taps unlock on the local Hive
  total and the late response still reconciles in the background (guarded by
  a generation counter so it cannot resurrect a session that was reset). Seed uses API
  `current_count` (active session) via `GET /accumulators/{parent_id}`, not
  `total_counted` (lifetime history). When `accumulator_id` is null — fresh
  install or after reset — the client keeps the local session tally (0 after
  reset) and ignores a stale `current_count`.
- **`beadInRound = total % 108`, `rounds = total ~/ 108`** (`kBeadsPerRound`).
- Taps are blocked while `isSeeding`; a failed seed (no user id) shows a
  retry (`seedFailed`). An API error falls back to the local total and
  enables counting.

### User-id resolution (important)

`mala_providers.resolveMalaUserId()` reads the **persisted** `currentUserId`
(`StorageKeys.currentUserId`, written at login *before* auth state flips) and
only falls back to `userProvider.user?.id`. This avoids a race where the screen
is reachable (auth gate passes) but the async profile fetch hasn't populated
`userProvider` yet. The counter caches the resolved id (`_userId`) on a
successful seed so the synchronous `incrementBead` can persist taps.

The local store **and** the sync manager must use the *same* id (the counter
writes Hive taps keyed by it; the sync manager reads dirty entries by it), so
both resolve through `resolveMalaUserId` (the sync manager's `currentUserId`
callback is async).

## Sync (`MalaSyncManager`)

App-scoped (`malaSyncManagerProvider`, kept alive for the app lifetime),
observes lifecycle + connectivity. Reads dirty entries straight from Hive, so it
flushes even after the user leaves the screen.

- **Triggers:** launch, each tap (debounced 5s), round completion (immediate),
  background/pause, connectivity reconnect, screen-leave, logout
  (`AuthNotifier` flushes before clearing the session).
- **Callbacks:** `onPersonalCountSynced` (counter refreshes `totalCounted`) and
  `onGroupCountSynced` (group lifetime totals refetch). `flushAndSettle()`
  flushes and waits for the sweep so callers can refetch server counts.
- **Flow per dirty preset:** create the accumulator once if `accumulatorId` is
  null (POST), then PUT the absolute total. On success, `max()`-merge the
  returned total into local `total`/`syncedTotal` and add the synced delta to
  `totalCounted`.
- **Failure:** entry stays dirty; exponential backoff retry (cap 60s).
- Concurrent triggers collapse via an `_isSyncing`/`_dirty` guard.

### Reset

1. Optional **PUT** if `total > syncedTotal` (flush unsynced taps to the
   active accumulator so lifetime totals on that record are preserved).
2. **DELETE** `/accumulators/user/{id}` — soft-delete the active session.
3. **`clearSession()`** locally — `total=0`, `syncedTotal=0`, `accumulatorId=null`.
4. Next tap/sync: **POST** (lazy create) + **PUT** as on first use.

Re-entry runs `seed()` again; with no active `accumulator_id`, the on-screen
count stays at 0 even if the parent detail echoes a non-zero `current_count`.

### Group reset

Same pattern as personal reset, scoped to one joined group:

1. Optional **POST** if the local group entry is dirty (flush unsynced taps so
   lifetime totals on the deleted record are preserved).
2. **DELETE** `/group-accumulators/{group_accumulator_id}` — soft-delete the
   active group session.
3. **`clearGroupSession()`** locally — group `total=0`, `syncedTotal=0` in
   `mala_group_counts`; the user remains joined.
4. Next tap/sync: **POST** the new absolute session count as counting resumes.

After a successful group reset, providers are invalidated so session counts
re-seed from detail (`joinedGroupUserCountsProvider`) and lifetime totals
refresh from the groups list (`joinedAccumulatorGroupsProvider`).

## Group counting: session vs lifetime

Group accumulators expose **two different user counts** from two endpoints:

| Source | Field | Meaning | Used for |
| --- | --- | --- | --- |
| `GET /accumulators/{presetId}/groups` | `user_total_count` | Lifetime total across all sessions for that group | [GroupAccumulationsSheet] row labels only |
| `GET /group-accumulators/{id}` (group_profile) | `user.total_count` | Active session count (resets on DELETE) | Mala counter, bead taps, Hive, background sync |

**On-screen counter (`_CounterBlock` / bead arc):** when a group is selected,
shows the **session** count from [groupAccumulationCountsProvider] (Hive +
`joinedGroupUserCountsProvider` seed). Resets to 0 after a group reset.

**Accumulations sheet:** group rows show **`AccumulatorGroup.userTotalCount`**
(lifetime from the groups list), plus any **unsynced local taps**
(`displayLifetimeCount` = API baseline + dirty tail). The sheet watches
[joinedAccumulatorGroupsProvider] and [groupAccumulationCountsProvider] so counts
update live; after a successful group POST the groups list is refetched. Lifetime
does not drop to 0 when the active session is reset.

**Personal row in the sheet:** shows the personal **lifetime** total,
`MalaCounterNotifier.displayLifetimeCount` (`totalCounted` from
`GET /accumulators/{parent_id}` plus unsynced taps). The header shows
"My total | Group total"; rows are split into Events and Groups sections
(`accumulation_sheet_display.dart`) and ended accumulations are omitted.

Providers:

- [joinedAccumulatorGroupsProvider] — groups list metadata + `userTotalCount`
  (lifetime).
- [joinedGroupUserCountsProvider] — fetches detail per joined group to seed
  session counts (`user.total_count`).
- [groupAccumulationCountsProvider] — local session state, increments on tap,
  `mergeFromServerCounts()` reconciles with detail API, `resetCount()` for
  group reset.

### Carousel order (latest used first)

Each catalogue row has `last_used_at`: when the user last counted on that
preset, personal or in a space accumulation built on it (`null` if never or
without a token). A reset keeps it; changing images doesn't move it. It is
cached in Hive with the rest of the row and carried onto `Mantra.lastUsedAt`.
The list's `last_used_id` is parsed but not used: it can name a preset that
isn't in the list.

Only `MalaScreen` reorders (`latestUsedFirst` in
`presentation/utils/mala_carousel_order.dart`): used presets newest first,
then never-used ones in server order, then joined space mantras. The carousel
opens on index 0, so it opens on the latest-used mantra; `initialPresetId`
still wins. The select-session screen and the group hero card keep the
server order.

- **Pinned for the life of the screen.** The order is worked out on the first
  non-empty catalogue and kept as preset ids (`_pinnedOrder`). A refresh
  updates each mantra's content but not its position (`inPinnedOrder`); new
  presets go at the end. A new order shows the next time the screen opens.
  Otherwise a refresh (e.g. after counting on another device) would move the
  page under the user's thumb.
- **The shown mantra is kept by id.** A refresh can still add or drop items
  before the one on screen: a new preset lands before the joined space
  mantras, and a removed preset or a changed space list shifts the rest.
  `MalaScreen` keeps the shown item's `presetId` (`_selectedId`) and finds
  its index again on every build, so the next tap counts into the same
  mantra. If that item itself is gone, the nearest position is shown.
- **Local override.** The server only knows synced counts. Each counted bead
  or added rounds on a preset (personal or group) writes `{preset_id, at}` to
  SharedPreferences under `mala_last_used_preset_{userId}`
  (`MalaLastUsedStore`, at most every 30 s per preset). When ordering, that
  preset's time is the later of the server's and the local one.
- `lastUsedAt` is not in `Mantra.props`: a `Mantra` keys `malaCounterProvider`,
  and a refresh that only moves it must not restart the counter.
- **Refreshed on entry.** `malaCatalogueProvider` is kept alive, so each
  `MalaScreen` open calls `malaCatalogueRefreshProvider`, which fetches the
  catalogue and writes it to Hive (failures are ignored). One fetch per
  account and language runs at a time: a first load with no cache joins the
  entry refresh instead of downloading every page again. The screen's own order is already pinned from
  what was loaded, so counts made on another device order the next visit,
  not this one.
- **Per account.** Rows carry the user's own `last_used_at`, so the Hive
  catalogue is keyed `catalogue:v3:{userId}:{language}` and
  `malaCatalogueProvider` watches the signed-in state, rebuilding on logout
  and login. Older shared keys (`catalogue:v2:{language}`,
  `catalogue:{language}`) are only an offline fallback, served without usage
  times, and deleted once a v3 catalogue is written.
- The first open after updating from a build without this has no v3 cache,
  so it loads from the network (or a legacy cache offline, in server order).

### Preset catalogue request and tradition filtering

`MalaRemoteDataSource.fetchPresets` sends:

```
GET /api/v2/accumulations?owner_type=platform&skip=0&limit=100&language=<content language>
Authorization: Bearer <token>    (AuthInterceptor)
X-Timezone: <IANA zone>          (TimezoneInterceptor)
```

It pages by 100 until `total` is reached. `search` is added only by the
accumulation search screen. `no_cache` is a client-side Dio extra, not sent.

Backend parameters the app does **not** send, and their defaults:

| Param | Default | Effect |
| --- | --- | --- |
| `tradition` | none | The backend uses the caller's **saved traditions** (see below). |
| `show_recitations` | `false` | Text-linked (recitation) presets are excluded. |
| `include_spaces` | `false` | No `space_accumulators`; joined space mantras load via `joinedSpaceMantrasProvider`. |

**Tradition filter (backend `pecha_api/traditions/tradition_filter.py`).**
Because the request carries a valid token and no `tradition`, the backend
returns only presets of the user's saved traditions (`GET /users/me/traditions`)
plus presets with no tradition. Anonymous callers, invalid tokens, and users
with no saved tradition get every preset. So `curl` without a token does
**not** reproduce what the app sees — test with the user's token.

If the saved traditions match no preset, the API returns
`{accumulators: [], total: 0}` with 200 and the app caches that `[]` under
`catalogue:v3:{userId}:{language}`. `mala_screen.dart` merges presets with eligible
joined space mantras before its empty check, so the screen shows
`mala_no_mantras` ("No mantras available") only when **both** lists are
empty; a user with a joined space mantra still sees that one. It is the empty
state, not an error view, so it has no retry button.

Changing the saved tradition in Edit Profile does **not** refresh the Mala
screen right away: `malaCatalogueProvider` is not auto-disposed and only
rebuilds on content-language or sign-in changes, and saving traditions
invalidates only `traditionTagFilterProvider`. The next Mala open does: the
cached list shows first, then the entry refresh replaces it (new presets go
after the pinned ones, removed ones drop out).

Seen on prod 2026-11-16: presets were tagged tibetan 8, pali 1, chinese (Mahayana) 0,
untagged 0, so Mahayana-only users got an empty Mala screen.

## Local store (`MalaLocalDataSource`)

Hive box `mala_counts`, keys `userId:presetId`, value = JSON `LocalMalaState`
(`total`, `syncedTotal`, `totalCounted`, `accumulatorId`, `beadImageUrl`,
`beadImageBase64`). The same box also caches the preset catalogue per
account under `catalogue:v3:{userId}:{language}`. `isDirty =
total > syncedTotal`. `pruneSynced` removes fully-synced entries (keeps dirty
tails); it currently has no caller.

Group counts use a separate Hive box `mala_group_counts`, keys
`userId:groupAccumulatorId`, value = JSON `LocalGroupMalaState` (`total`,
`syncedTotal`). Same dirty model; flushed by [MalaSyncManager] via
`POST /group-accumulators/{id}`.

Opened once in app bootstrap via `MalaLocalDataSource.init()`.

## Bead artwork & caching

`MalaCounterNotifier` downloads bead artwork via dio during seed (not in the
widget). URLs from the API are **presigned S3 links** that expire (~1 hour), so
stale Hive URLs are retried against fresh catalogue / detail URLs before giving
up. Successful downloads are stored as **`beadImageBase64`** in Hive.

`MalaBeads` renders **`beadImageBytes` only** (MemoryImage). While bytes are
still downloading — or when download fails — the painter draws a gradient bead
(`_drawDrawnBead`). This avoids loading expired presigned URLs directly in the
widget layer (which would log ImageResourceService 403 errors).

- **Preset source.** `Mantra.beadImageUrl` resolves to the mantra-level
  `mala_image_url` first, falling back to the accumulator-level one.
- **Offline.** Persisted bytes in `LocalMalaState` let the strand render on a
  cold start without network.
- **No flash.** `MalaCounterNotifier` prefills the cached bytes synchronously
  (via `malaUserIdSync`) and `MalaBeads` keeps decoded skins in a small
  in-memory cache keyed by content hash, so remounts paint on the first frame.

## Bead input & feedback

Counting is triggered two ways over the bead region (`HitTestBehavior.opaque`),
both +1 and both blocked while seeding:
- **Tap** anywhere on the strand.
- **Right-to-left swipe** — a leftward drag past `_kSwipeDistance` (24px) or a
  leftward fling past `_kFlingVelocity` (200px/s), matching the strand's right→
  left motion. Left-to-right is ignored (counting is monotonic).

Each `incrementBead`:
1. `_sound?.play()` — `MalaSoundPlayer` plays `AppAssets.malaSound`
   (`assets/audios/mala-sound.wav`), loaded once and restarted from the top per
   tap so rapid counting stays responsive. Provider:
   `malaSoundPlayerProvider` (`Provider.autoDispose`, disposed with the screen).
2. `HapticFeedback.lightImpact()` (and `mediumImpact()` on round completion).

## Bead arc rendering (`MalaBeads` / `_MalaBeadsPainter`)

A `CustomPaint` strand that advances **forward only** (counting is monotonic).

- **Curve:** a quadratic Bézier from bottom-left (`a`) up to top-right (`b`) with
  the control point (`c`) **above the chord** so the arc bows *outward* (convex
  toward the bottom-right) — flat near the top-right, steepening toward the
  bottom-left. Drawn as the red mala thread (`threadColor`).
- **Even spacing:** beads are spaced by **arc length**, not by the Bézier
  parameter `t` (a Bézier isn't uniform in `t`, which would bunch/overlap beads
  at the ends). An arc-length lookup table (sampled over an extended `t` range)
  maps a bead's position → `t`, so on-screen spacing is constant and the strand
  fills out to the edges.
- **One gap:** a single fixed gap (the counting point, right-of-centre) where
  the red thread shows through. Implemented by pushing beads right of the focal
  slot by `_gap` bead-steps via a `_smoothstep`, so the front-right bead glides
  smoothly *through* the gap on a tap.
- **Animation:** the slide plays **only on a genuine +1 count**
  (`widget.total == oldWidget.total + 1`): the strand slides one bead
  **right → left** (the front-right bead crosses the gap to join the left pile,
  a new bead enters from the top-right). `AnimationController` 280ms,
  `Curves.easeOut`, forward only — never `reverse()`. Any other total change —
  **switching mantras** or the initial **seed load** — snaps straight to the new
  count with no slide (`didUpdateWidget`).

### Tuning knobs (all in `_MalaBeadsPainter`)

| Constant | Meaning | Current |
| --- | --- | --- |
| `_radiusFactor` | bead radius as a fraction of width | `0.075` (diameter ≈ 15% of width) |
| `_spacingFactor` | centre-to-centre spacing × radius | `2.0` (touching) |
| `_focalT` | arc position (0..1) of the gap | `0.56` |
| `_gap` | empty bead-steps of thread at the gap | `1.0` |
| `_from` / `_to` | candidate bead indices drawn (rest skipped/clipped) | `-9 / 9` |
| `a`, `c`, `b` | Bézier points (overall curvature) | see `paint()` |

> Note: a `canvas.clipRect(...)` line exists in `paint()` to cut overflow at the
> edges; toggle it depending on whether beads should be hard-cut at the bounds.

## Screen layout (`MalaScreen`)

Below the app bar, the body is a vertical column (24px horizontal padding, 16px
bottom):

1. **`MantraSwitcher`** — `Expanded(flex: 48)` when any mantra has deity
   artwork, `flex: 26` otherwise (so the layout does not jump while swiping).
   Shows the artwork plus a `MantraMarquee` band whose speed comes from
   `malaSettingsProvider.mantraSpeed`. Infinite looping carousel
   (unbounded `PageView` seeded at `_loopBase * length + index`, mapped back
   with `page % length`); swipe or tap chevrons to wrap. The screen owns
   `_index`; the carousel reports settles via `onIndexChanged`. With one mantra
   it locks (no swipe, chevrons disabled).
2. **`_CounterBlock`** — `n/108` bead-in-round and rounds count (+ the
   add-rounds button), left-aligned, or right-aligned and with the bead arc
   mirrored when `leftHanded` is on (toggle in the app bar). Tibetan locale
   renders Tibetan digits.
3. **`MalaBeads`** — `Expanded(flex: 30)` with artwork / `flex: 42` without,
   top-aligned in a canvas sized to ~85% of the available height.
4. **`GroupAccumulationsBar`** — fixed 40px slot at the bottom (see below).

Route `/mala` (login-gated) takes `extra` keys `presetId`,
`groupAccumulatorId` and `groupAccumulatorEnded`. When opened on an ended group
accumulation, the add-rounds button and the groups bar are hidden.

States: skeleton (loading), error+retry (catalogue or seed failure), data.

## Group accumulations bar (`GroupAccumulationsBar`)

Entry point for group counting tied to the current preset. Fetched per mantra via
`joinedAccumulatorGroupsProvider(presetId)` →
`MalaRepository.getJoinedAccumulatorGroups()` →
`GET /accumulators/{presetId}/groups?joined_only=true`.

- **Visibility:** the grey pill appears only when the response contains at
  least one group. Loading, error, and empty responses show nothing inside the
  slot.
- **Layout stability:** the widget always reserves **40px height**
  (`GroupAccumulationsBar.barHeight`) so the bead arc does not jump when the
  request resolves.
- **Preview:** up to two overlapping circular avatars (28px, 10px overlap) plus
  a chevron. Tapping opens [GroupAccumulationsSheet] with the cached groups list.
- **Selection:** [malaAccumulationSelectionProvider] persists the active source
  per preset (`personal` or `group:{uuid}` in SharedPreferences). The mala
  counter and bead arc display the selected **session** total; taps increment
  personal or group session counts accordingly. Group session counts are
  persisted locally per `(userId, groupAccumulatorId)` and synced in the
  background by [MalaSyncManager] (debounced tap flush, round-complete immediate
  flush, lifecycle + reconnect), mirroring personal accumulation.
- **Images:** group `image` is parsed as `ImageUrlModel` (`thumbnail` /
  `medium` / `original`) via `ImageModel.fromJsonMap()` and mapped to
  `ResponsiveImage` on the entity. Avatars render through `ResponsiveCoverImage`
  so the thumbnail tier is picked for the small circle.

`AccumulatorGroup` entity fields used today: `groupAccumulatorId`, `groupId`,
`title`, `image`, `userTotalCount` (lifetime — sheet display only), `isJoined`.
The DTO also carries `target_count`, dates, etc. — not yet mapped on the client.

On API failure the provider returns an empty list (bar stays hidden, slot
reserved).

## Group accumulations sheet (`GroupAccumulationsSheet`)

Opened from the bar pill. Receives the already-fetched [AccumulatorGroup] list
and reads the user's personal **lifetime** count for the current preset
(`displayLifetimeCount`).

- **User row:** name and avatar from [userProvider] (local cache written at
  login; refreshes via `GET /users/info` when the sheet opens and no user is
  cached yet). Tappable; selected
  row uses `AppColors.blue` / `AppColors.blueDark`. Count shows the personal
  lifetime total (see above).
- **Groups list:** each row shows group image, title, and a **lifetime** count
  (`userTotalCount` from the groups list + unsynced local taps). Not the session
  count used by the counter — so a group reset clears the counter but lifetime
  totals in the sheet stay visible. Watches providers for live updates. Tappable;
  accent colour on the active row.
- **Persistence:** selection survives app restarts via
  `StorageKeys.malaAccumulationSelectionPrefix` + preset id. Invalid group ids
  fall back to personal when the groups list reloads.

Offline mala rounds are added from the "+" button beside the rounds count.

## Mala settings (`MalaSettingsScreen`)

The ⋮ in the mala app bar pushes a full page (root navigator):

- **Add to my practices** (top; personal preset only).
- **Practice:** Mantra animation (shows the speed, or "Off"), Sound, Vibration,
  Reset count (presets only; personal or the selected group session).
- **Appearance:** Bead style (shows "Default" or the skin name), Change image.
  Hidden when the mantra has no id.
- **Save & share:** Bookmark / Bookmarked (personal preset only), Share.

A group accumulation's own mantra (space mantra) gets Practice without reset,
and Appearance.

**Mantra animation** (`MantraAnimationSheet`): a Play animation toggle and
speed chips 0.5x / 0.75x / 1x / 1.25x / 1.5x (`kMalaMantraSpeedPresets`).
Changes apply at once. With play off the marquees stand still (`animate:
false`) and the chips are disabled. A speed saved by an older build (the old
slider allowed up to 2x) is snapped to the nearest chip on load.

**Bead style** (`BeadStyleSheet`) and **Change image** (`ChangeImageSheet`)
are saved per mantra on the server (API v2), keyed by `mantra_id`, so a pick
shows on every accumulation of that mantra (presets, own and space
accumulations) and on every device. It never changes what others see.

| Call | Used for |
| --- | --- |
| `GET /api/v2/mantras/{mantra_id}/images` | `deity_images`: the Change image grid, in `display_order` |
| `GET /api/v2/mala-skins` | `mala_skins`: the Bead style grid |
| `GET /api/v2/users/me/mantras/{mantra_id}/appearance` | the user's picks (`null` = default) |
| `PATCH` the same path | save `deity_image_id` and/or `mala_skin_id`; `null` restores the default |

These paths are in `ApiConfig` (`mantrasV2Path`, `malaSkinsV2Path`,
`userMantrasV2Path`) and in `ProtectedRoutes`, so the token is always sent.
The older mala calls stay on v1.

- **`malaAppearanceProvider(mantraId)`** (autoDispose) loads the picks while a
  screen shows the mantra. `setDeityImage` / `setMalaSkin` PATCH and, on
  success, take the response as the new state, so the mala screen changes at
  once; they also refresh `mantraCountsProvider` and
  `joinedSpaceMantrasProvider`, which carry the pick too. On failure they
  return false and nothing changes; the sheet stays open with a "Couldn't
  save" toast (shown inside the sheet through `MalaSheetToastHost`).
- **The mala screen** (`watchMalaMantraImage`, `watchMalaBeadBytes`) draws
  the resolved `deity_image` / `mala_skin_url` (the pick, else the mantra's
  default). What the accumulation already holds only stands in while the
  appearance loads or fails, since it can still be an earlier pick. The image
  is looked up for the mantra on screen and its two neighbours only; the
  carousel wraps, so the first and last mantras count as neighbours.
- **Not cached:** `CacheInterceptor.isUserSpecificPath` also matches
  `/../v2/users/me/...`, so the appearance is read fresh each time.
- **Bead style:** the first tile, Default, is the bead the accumulation shows
  without a pick and saves `mala_skin_id: null`. The other tiles are the skins
  from `/mala-skins`, labelled by `MalaSkin.displayName` (`bodhi_seed` →
  "Bodhi seed").
- **Change image:** the default image is ticked until the user has a pick.
  Picking it again, or "Restore default" (enabled only while there is a pick),
  saves `deity_image_id: null`, so the user keeps following the default.
- Image URLs are presigned and expire, so none are stored; the lists are
  fetched each time a sheet opens.

## Analytics

`MalaAnalytics` (`presentation/utils/mala_analytics.dart`) owns the events:
`mala_screen_opened`, `mala_mantra_switched`, `mala_mode_changed`,
`mala_offline_rounds_added`, `mala_sync_failed`, plus the session events
`mala_session_started`, `mala_round_completed` and `mala_session_ended`, which
`MalaSessionTracker` groups from the first counted bead until the screen
closes, the app backgrounds, or five minutes pass without a bead.

## Tests (`test/features/mala/`)

- `mala_counter_notifier_test.dart` — seed merge, post-reset stale-count guard,
  offline-tail preservation, no-op while seeding, monotonic increment, round
  completion, fresh-install seed-at-0, `resetCount()` success/failure/mounted.
- `mala_sync_manager_test.dart` — create-once-then-update, absolute-total PUT,
  `max()` adoption, dirty-on-failure, logged-out no-op, per-user namespacing,
  group count POST flush + dirty-on-failure, group reset (flush-then-DELETE).
- `mala_beads_test.dart` — tap increments, right-to-left swipe increments,
  left-to-right doesn't, and disabled beads ignore both.
- Also: `accumulation_chant_counter_test.dart`,
  `mala_accumulation_selection_provider_test.dart`, `data/` (model + catalogue
  cache tests) and `presentation/{utils,widgets}/`.

`currentUserId` callbacks are async (`Future<String?> Function()`) in both the
notifier and sync manager.
