# Auth Feature

> **LLM context doc** — read this before changing anything under `lib/features/auth/`.

## Purpose

App-wide authentication and user profile. Firebase Authentication proves who the person is (Google, Apple, phone); its ID token is exchanged for the backend's own access and refresh tokens, which are the session. Backend stores user profile. Nearly every authenticated feature depends on this module. Full design: `docs/architecture/AUTH_IMPLEMENTATION.md`.

## User-facing functionality

- Firebase sign-in: Google, Apple (iOS), phone/SMS (own number + code screen). Google and Apple run in place (`AuthState.isSigningIn`, no splash); the button last used on this phone is tagged "Last used"
- New accounts the provider shared no name for are created with a filled-in name (`AccountNames`), never a form; phone accounts name themselves in onboarding
- One-time sign-out of the Auth0 session left by builds before the switch
- Guest mode ("continue as guest")
- Session restore on launch (offline-tolerant)
- Access token lifecycle (proactive + reactive refresh)
- Profile data/edit via `UserNotifier`: name, avatar, username, bio (the profile *screens* live in other features; `presentation/screens/profile_page.dart` is currently unreferenced)
- Account deletion
- Onboarding completion flag (route guards)
- `LoginDrawer` — reusable login prompt app-wide

## Architecture

```
auth/
├── auth.dart, auth_service.dart
├── data/            remote datasource, user_model, repository impl
│   └── session/     Firebase sign-in, token exchange/refresh API, token store, Auth0 cleanup
├── domain/          entities, repository interface, usecases (one file each)
└── presentation/    providers, notifiers, screens, state, widgets
```

## Key files

| Area | Files |
|------|-------|
| Session | `presentation/providers/auth_notifier.dart`, `auth_state.dart` |
| Profile | `presentation/providers/user_notifier.dart`, `user_state.dart` |
| Sign-in + session | `auth_service.dart` (singleton), `data/session/firebase_sign_in.dart`, `auth_token_api.dart`, `session_token_store.dart` |
| Token refresh | `auth_service.dart` (`getValidAccessToken` / `forceRefreshAccessToken`, single-flight `_refresh`), `core/network/auth_service_token_provider.dart`, `core/network/interceptors/retry_interceptor.dart` |
| Auth0 → Firebase | `data/session/legacy_auth0_cleanup.dart` (the only `auth0_flutter` use left; remove with the package) |
| Init | `domain/usecases/initialize_auth_usecase.dart` |
| Login UI | `presentation/widgets/login_drawer.dart`, `presentation/screens/login_page.dart`, `auth_buttons.dart`, `social_login_button.dart`, `presentation/screens/phone_login_screen.dart`, `presentation/utils/login_failure_text.dart` |
| Session side effects | `presentation/providers/user_session_bootstrap.dart` (clears auth-scoped HTTP cache + user providers on auth transitions) |
| Analytics | `presentation/utils/auth_analytics.dart` |
| Barrel | `auth.dart` |

## State management

- **`authProvider`** — session: login, logout, guest, init, onboarding flags
- **`userProvider`** — profile CRUD, separate from auth session
- Per-use-case providers in `use_case_providers.dart`

**Critical:** auth and user state are intentionally split. Do not merge them.

## Data sources

- **Firebase Authentication** (`firebase_auth`, `google_sign_in`) — proof of identity at sign-in only; signed out again at once
- **Backend API** — `POST /auth/firebase/exchange`, `POST /auth/refresh-token`, `GET/POST/PATCH/DELETE /users/...`
- **SharedPreferences** — guest mode, cached user ID (the key local data is stored under: the backend user id, or the Auth0-era id for the account that was signed in at the move to Firebase), sign-in method
- **`flutter_secure_storage`** — the session tokens (`SecureSessionTokenStore`)

## Cross-feature dependencies

- **Consumes:** onboarding (status), notifications (cleanup on logout), mala (sync reset)
- **Consumed by:** almost every feature via `authProvider` / `userProvider`

Side effects on logout (`AuthNotifier.logout`): unregister the push device (while the JWT is still valid), clear the auth-scoped HTTP cache, flush mala counts, settle pending prayer sends, clear local credentials + guest flag, clear `userProvider` and `currentUserId`, clear the pending deep-link route, cancel routine notifications, reset analytics identity.

A *permanent* mid-session refresh failure (nothing stored, or a refresh the backend refused — 401 anywhere, any 4xx on the reactive 401 path) calls `AuthNotifier.handleSessionExpired()` via the `RetryInterceptor` callback wired in `core/di/core_providers.dart`; it only flips state, clears credentials and resets analytics (lighter than `logout()`).

## Public API

Import from `features/auth/auth.dart`. Does **not** export `splash_screen.dart` or `user_session_bootstrap.dart`.

---

## How to make changes (LLM playbook)

### Principles

1. **Auth is app-critical** — prefer small, well-tested changes.
2. **One use case per file** in `domain/usecases/`.
3. **Auth epoch** — respect stale-async guards after logout; check existing patterns in `AuthNotifier`.
4. **Offline-first restore** — unknown onboarding status fail-opens to home; retry in background.
5. **Single-flight token refresh** — do not add parallel refresh paths.
6. **Firebase's user belongs to live updates** — sign-in takes the ID token and signs out of Firebase straight away (`FirebaseSignInImpl._proofFor`). `FirebaseSessionNotifier` owns the app's Firebase user (custom token, uid = backend user id). Never leave a Google/Apple/phone Firebase user signed in.
7. **Sign-in failures are `LoginFailure`s** — add a `LoginFailureReason` and word it in `login_failure_text.dart`; don't show raw error text.

### Do

- Add new profile fields: entity → model → datasource → repository → use case → `UserNotifier`
- Gate new protected API calls via existing token use cases / interceptors
- Use `LoginDrawer` for guest gating in other features (don't duplicate login UI)
- Persist `currentUserId` before auth state flips (race guard used by mala, timer, etc.)

### Don't

- Don't store tokens in SharedPreferences — `SessionTokenStore` only
- Don't read the sign-in provider from the user id. Use `StorageKeys.signInMethod`
- Don't compare `StorageKeys.currentUserId` with ids the backend returns: it is a local key. Use the profile's id (`userProvider`)
- Don't add a name prompt to sign-in: a missing name is filled in (`AccountNames.complete`) and replaced when the owner saves a display name (`UserNotifier.saveProfile`)
- Don't merge `AuthNotifier` and `UserNotifier`
- Don't break guest mode flows when adding auth requirements
- Don't skip logout cleanup hooks (notifications, mala sync, cache)

### Common tasks

| Task | Where to start |
|------|----------------|
| New profile field | `domain/entities/user.dart` → model → remote datasource → use case → `UserNotifier` |
| New login method | `data/session/firebase_sign_in.dart`, `auth_service.dart`, `presentation/utils/start_sign_in.dart` (every button starts here), `auth_buttons.dart` / `login_drawer.dart` / the guest view in `more/presentation/me_screen.dart`, `auth_notifier.dart` |
| Route guard change | `core/config/router/route_guard.dart` + `auth_state.dart` |
| Token issue | `auth_service.dart`, `core/network/interceptors/auth_interceptor.dart`, `retry_interceptor.dart` (the `Get/ForceRefreshAccessTokenUseCase` classes exist but are not used by the request path) |

### Testing

- Test logout clears dependent feature state
- Test offline session restore
- Test guest → login transition without stale user ID races
- `AuthService.forTesting` takes fakes for the token store, the token API, Firebase sign-in and the Auth0 cleanup (`test/features/auth/auth_service_test.dart`)
