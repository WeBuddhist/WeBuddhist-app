# Poems Feature

> **LLM context doc** — read this before changing anything under `lib/features/poems/`.

## Purpose

Full-screen, story-style poems viewer: swipe horizontally between published
poems, each with a collapsing cover image, title, body, author and chapter.
Home shows three poems as a row of cards inside its feed (the next card
peeks in from the right); tapping one opens the viewer on that poem.

## User-facing functionality

- Horizontal `PageView` of poems, lazily paged (20 per page, next page when
  within 3 of the end)
- Title moves into the top bar once it scrolls out of view
- Scrollable dots indicator for long lists
- Share a poem (deep link `/open/poem/:poemId` → `/home/poems?poemId=…`)
- Opening on a specific poem: found in the first page, else fetched by id
  and pinned to the front

## Architecture

```
poems/
├── data/
│   ├── datasource/poems_remote_datasource.dart   # GET /poems, GET /poems/{id}
│   ├── models/poem_model.dart
│   └── repositories/poems_repository_impl.dart   # exceptions → Failure
├── domain/
│   ├── entities/        Poem, PoemsPage
│   └── repositories/poems_repository.dart
└── presentation/
    ├── providers/   poems_providers (DI, language code, title visibility),
    │                poems_viewer_notifier
    ├── screens/poems_viewer_screen.dart
    ├── utils/poem_share.dart
    └── widgets/     poem_story_page, poem_dots_indicator, poem_preview_card
```

## Key files

| Area | Files |
|------|-------|
| Viewer | `presentation/screens/poems_viewer_screen.dart` |
| Paging state | `poemsViewerProvider(initialPoemId)` in `poems_viewer_notifier.dart` |
| Home preview | `home/presentation/providers/home_poems_preview_provider.dart`, `home/.../poems_section.dart`, `poem_preview_card.dart` |
| Route | `core/config/router/app_router.dart` (`home-poems`, `open-poem`) |
| Share | `presentation/utils/poem_share.dart` |

## State management

- `poemsViewerProvider` — `StateNotifierProvider.autoDispose.family` keyed
  by the initial poem id; rebuilt when `contentLanguageProvider` changes
  (the screen resets its `PageController` then).
- `poemViewerAppBarTitleVisibleProvider(poemId)` — set by each page from
  scroll notifications.

## Data sources

- **Main API** via `dioProvider`. `/poems` is optional-auth: guests get
  All traditions poems; with a token the backend adds poems for the caller's
  saved traditions (no `tradition` param is sent, so all of them count).
  The feed is per user, so it always skips the HTTP cache (`no_cache`).
- Home's stored preview is keyed by user and `userTraditionCodesProvider`
  (`onboarding/.../user_tradition_codes_provider.dart`); it waits for the
  codes and re-fetches when they change. Invalidate that provider wherever
  the user's traditions are saved.
- `language` is the API's uppercase enum — use `poemsApiLanguageCode`.
- The list envelope is tolerated as a bare array or
  `{poems|items|results|data, total|count}`; without a total, `hasMore` is
  "page was full".

## Cross-feature dependencies

- **home** — preview section and provider.
- **core** — router, deep links, share URL shortener, share analytics.

---

## How to make changes (LLM playbook)

### Do

- Keep the viewer's `skip` counting raw page sizes (not de-duplicated
  ones) so offsets stay aligned with the server.
- Check `mounted` after every await in the notifier.

### Don't

- Don't send the lowercase content language to the API.
- Don't send `tradition` on `/poems` for signed-in users: it narrows the
  feed to one tradition instead of all of theirs.
- Don't put `/poems` through the HTTP cache; its keys aren't per user.

### Testing

- Envelope parsing and `hasMore` with and without a total.
- Initial poem: in first page, fetched by id, fetch failure.
- Load-more de-duplication and failure (keeps `hasMore` for retry).
- Home preview: keyed by tradition codes, waits for them, re-fetches on change.
