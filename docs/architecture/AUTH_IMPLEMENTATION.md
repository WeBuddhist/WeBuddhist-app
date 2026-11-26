# Authentication Architecture

## Overview

People sign in with **Firebase Authentication** (Google, Apple or phone).
Firebase only proves who they are: the app exchanges the Firebase **ID token**
with the backend for the backend's own **access and refresh tokens**, and
those are the session from then on. The access token is the API bearer.

The web app and the Studio work the same way (backend doc:
`documentation/firebase-auth.md` in WeBuddhist-Backend).

> Rewritten Nov 2026 for the move from Auth0 to Firebase. The Oct 2026
> version described Auth0 Universal Login, the Auth0 access token as the
> bearer and the Auth0 credentials manager as the refresh path; none of that
> is used any more. See [Moving from Auth0](#moving-from-auth0).

---

## Architecture Diagram

```
 LoginPage / LoginDrawer ── Google, Apple ──┐
 PhoneLoginScreen ── number, SMS code ──────┤
                                            ▼
                              AuthNotifier (authProvider)
                                            │  use cases (domain/usecases)
                                            ▼
                                   AuthRepositoryImpl
                                            │
                                            ▼
                         AuthService (singleton, auth_service.dart)
                           │            │                 │
              FirebaseSignIn       AuthTokenApi      SessionTokenStore
        (firebase_auth +        (bare Dio)           (Keychain / encrypted
         google_sign_in)   POST /auth/firebase/exchange   storage)
                           POST /auth/refresh-token

 Dio (dioProvider)
   AuthInterceptor ──► AuthServiceTokenProvider ──► AuthService.getValidAccessToken()
   RetryInterceptor (401 / bearer-less 403) ──────► AuthService.forceRefreshAccessToken()
```

All of `data/session/` sits behind `AuthService`; nothing else imports it.

---

## Sign-in

1. `FirebaseSignIn` signs in with the provider and reads the Firebase ID token.
   - **Google:** `google_sign_in` → Google ID token →
     `FirebaseAuth.signInWithCredential`.
   - **Apple:** `FirebaseAuth.signInWithProvider(AppleAuthProvider)` — the
     native sheet on iOS. The button is only shown on iOS.
   - **Phone:** `FirebaseAuth.verifyPhoneNumber` sends an SMS; the code is
     turned into a credential and signed in. Android can verify some numbers
     without a code, which completes the sign-in from the number step, and
     it can read the SMS itself, which completes it from the code step
     without typing (`PhoneCodeStart.autoSignIn`). A code typed first wins:
     the automatic sign-in belongs to an older attempt and is dropped.
2. It **signs out of Firebase again at once**. The token stays valid for the
   exchange (a client sign-out does not revoke it).
3. `AuthTokenApi.exchangeFirebaseToken` posts it to
   `POST /auth/firebase/exchange` and gets `auth.access_token` and
   `auth.refresh_token`.
4. `AuthService` stores them in `SessionTokenStore` and records the sign-in
   method (`StorageKeys.signInMethod`: `google`, `apple` or `phone`).
5. `AuthNotifier._handleSuccessfulLogin` stores the local user id (the access
   token's `sub`, the **backend user id** — or, for the account that was
   signed in when the app moved off Auth0, the id it had then, see
   [Moving from Auth0](#moving-from-auth0)), identifies the user for
   analytics, prefetches onboarding status and the profile, then flips auth
   state.

A sign-in the person has left cannot finish behind their back. `AuthService`
counts attempts (`_loginAttempt`): starting another sign-in or signing out
bumps it, and an exchange that answers under an older value is dropped
instead of being stored. The phone screen also refuses to close while a code
is being sent or checked.

### Where the person is while signing in

Every "Continue with …" button (login page, login drawer, guest Me tab)
starts through `startSignIn`.

- **Google and Apple** run in place. `AuthNotifier.login` sets
  `AuthState.isSigningIn`, and the buttons give way to a spinner. It does
  **not** set `isLoading`: the route guard shows the splash on that, which
  would replace the screen the person is on. So a guest who signs in from a
  prompt carries on where they were, and one who cancels or fails stays put
  and sees why (`AuthState.loginError`).
- **Phone** opens `PhoneLoginScreen` over wherever it started, and closes
  itself once signed in.

A new account still goes to onboarding: the route guard sends it there when
auth state turns signed in with onboarding not done.

### "Last used"

The method last used to sign in on this phone is kept in
`StorageKeys.lastSignInMethod`, which survives signing out, and the matching
button carries a "Last used" tag (`LastUsedTag`, via
`lastSignInMethodProvider`). Someone who picks a different method than before
gets a new, empty account, and after the move from Auth0 everyone has to
choose again: the Auth0 cleanup fills it in from the old login's subject
(`google-oauth2|…`, `apple|…`, `sms|…`).

### Why Firebase is signed out straight away

The app has one Firebase user, and it belongs to live updates:
`FirebaseSessionNotifier` signs in with a **custom token whose uid is the
backend user id**, and the Firestore rules depend on that uid. A Google or
phone Firebase user left signed in would be mistaken for it on the next
launch. So a sign-in user never outlives `FirebaseSignInImpl._proofFor`.

The backend also accepts a Firebase ID token directly as a bearer. The app
does not use that, for the same reason: one Firebase app holds one user.

### New accounts need a name, and nobody is asked for one

For an account that does not exist yet and has no first and last name, the
exchange answers **422** ("First name and last name are required for a new
profile"). Phone sign-in never has a name; Apple can withhold it; a Google
account can have a single name.

The app does not ask during sign-in. `AuthService._exchange` sends the
exchange again, **same Firebase token**, with the gap filled by
`AccountNames.complete`:

| The provider shared | Sent as first / last |
|---|---|
| Nothing (phone, or Apple withholding the name) | `WeBuddhist` / `User` — `AccountNames.placeholder`, the same placeholder the Auth0 account creation used |
| One name (`Tenzin`) | `Tenzin` / `Tenzin` |

The filled-in names go only on that second try, so an existing account is
never sent a made-up name.

The owner then names the account:
- **Phone accounts** get the onboarding step "What should we call you?"
  (`OnboardingScreenProfile`: display name and username), as before.
  `onboardingStepsProvider` adds it when `StorageKeys.signInMethod` is
  `phone`.
- **Any account still on the placeholder** has its first and last name
  replaced by the display name its owner saves, in onboarding or Edit profile
  (`UserNotifier.saveProfile`). Chat and member lists show people by first
  and last name, so this is what stops them showing "WeBuddhist User".

A first-time account of any kind goes through onboarding as usual: the
backend reports onboarding as not completed and the route guard sends it
there.

### Failures

Every sign-in failure reaches the UI as a `LoginFailure` with a
`LoginFailureReason` (`cancelled`, `invalidCode`, `codeExpired`,
`tooManyRequests`, `network`, `emailNotVerified`, …). `loginFailureText`
words it: on the phone screen for phone sign-in, under the buttons of the
login page and drawer for Google and Apple (`AuthState.loginError`). `loginFailureReasonFor` in `auth_repository_impl.dart` maps the
codes: `AuthService`'s own, Firebase's (`invalid-verification-code`, …) and
`http_<status>` from the exchange.

---

## The session

| | |
|---|---|
| Access token | Backend JWT; `sub` = backend user id, plus `email` / `phone_number`. The API bearer. |
| Refresh token | Sent to `POST /auth/refresh-token` (`{ "token": … }`) for a new access token. **The backend does not renew it**, so a session ends when it expires. |
| Storage | `SecureSessionTokenStore`: `flutter_secure_storage` (Keychain, `first_unlock`, on iOS; encrypted storage on Android), cached in memory after the first read. The pair is **one** stored value, so an interrupted write can never leave one account's access token beside another's refresh token. |

### Refresh

- **Ahead of a request:** `getValidAccessToken()` returns the stored token,
  or refreshes first when it is within 120 s of expiry.
- **After a 401:** `RetryInterceptor` calls `forceRefreshAccessToken()` and
  replays the queued requests with the new token.
- **One at a time:** every caller shares the refresh in flight
  (`_inflightRefresh`). Do not add another refresh path.
- **Session generation:** a counter bumped on login and logout. A refresh
  that began under one session neither stores its token in the next nor
  clears it.

### When a session ends

A session ends only on evidence, never on a failed read or a timeout.

| What happened | `AuthException.code` | Launch restore | After a 401 |
|---|---|---|---|
| Nothing stored | `no_session` | logged out | logged out |
| Refresh answered **401** (expired, revoked, account gone) | `refresh_rejected` — tokens cleared | logged out | logged out |
| Refresh answered another **4xx** | `refresh_refused` | session kept | logged out |
| Offline, timeout, **5xx**, keystore error | — | session kept | session kept |

`AuthService.isSessionPermanentlyLost` covers the first two rows;
`isTokenRenewalFailed` adds the third. The 401 path is stricter because the
server has just answered: we are provably online and talking to the right
backend, so a refused refresh there would otherwise loop 401s forever.

`AuthNotifier.handleSessionExpired()` (wired in `core/di/core_providers.dart`)
flips state, clears the tokens and resets analytics.

---

## Moving from Auth0

Builds before this one kept an Auth0 session in the Auth0 credentials
manager, which this build cannot use. Like the web app, the first launch
after updating **signs that session out once**; the person signs in again and
lands in the same account, because the backend matches on verified email or
phone number.

`LegacyAuth0CleanupImpl` (run from `AuthService.initialize`):

- Recognises an Auth0 build by the tenant config it cached in preferences
  (`auth0_cfg_domain` / `auth0_cfg_client_id`).
- Clears the Auth0 credentials (local only: no call to Auth0, works offline).
- Remembers the id local data was keyed by (below), then removes
  `currentUserId` and the cached profile.
- Runs once (`legacy_auth0_session_cleared`). A failed clear is retried on
  the next launch.

`AuthNotifier` then resets the analytics identity. Guests stay guests.

### The local user id survives the move

`StorageKeys.currentUserId` keys local data: mala counts, pending timer
stops, pending plan actions and series enrolments, and every per-user cache.
It is also the analytics identity. Under Auth0 it was the Auth0 subject
(`google-oauth2|…`); a fresh sign-in now gives the backend user id. Switching
ids would strand anything not yet sent to the server — counts made offline
before updating would never be found again.

So the cleanup stores the old id (`legacyAuth0UserId`) next to that account's
backend id (`legacyAuth0BackendUserId`, read from the cached profile), and
`AuthNotifier._localUserIdFor` keeps using the old id whenever **that same
backend account** signs in on this phone. Any other account gets its backend
id. The pair is kept for good: local data is not deleted on logout, so the
account must find it again on every later sign-in.

Consequences:
- `currentUserId` is a local key, not always the backend id. Compare with ids
  from the backend using the profile (`userProvider`).
- Returning users keep their analytics identity.
- A profile cached before profiles carried an `id` cannot be matched; that
  account starts on its backend id and data left under the old one stays put.

**To remove later**, once builds older than the switch are no longer
supported: `auth0_flutter` in `pubspec.yaml`, `legacy_auth0_cleanup.dart`,
the Auth0 `RedirectActivity` and `manifestPlaceholders` on Android, the
`auth0` URL scheme in `Info.plist`, `AUTH0_SCHEME` in the xcconfigs, and the
`webcredentials:` associated domain plus `AUTH0_DOMAIN` in the entitlements
template and the iOS workflow.

---

## Native setup

Everything is in the Firebase project `webuddhist-app`, shared with the web
app, the Studio and the backend. The ID token's audience is the project, so
the app must stay in it.

### iOS

- `GoogleService-Info.plist` per flavor (`ios/Runner/config/<flavor>/`) must
  carry `CLIENT_ID` and `REVERSED_CLIENT_ID`. `google_sign_in` is given the
  client id from the bundled file at runtime (`FirebaseSignInImpl`).
- `GOOGLE_REVERSED_CLIENT_ID` in `ios/Flutter/<flavor>-*.xcconfig` feeds the
  `google-sign-in` URL scheme in `Info.plist`. It must match that flavor's
  plist. Phone sign-in's reCAPTCHA fallback returns on the same scheme.
- `com.apple.developer.applesignin` in `Runner.entitlements`,
  `Runner-dev.entitlements` and `Runner.entitlements.template`. The App IDs
  need the *Sign in with Apple* capability, and the provisioning profiles CI
  uses must be regenerated after it is enabled.
- Phone sign-in verifies the app with a silent push (APNs is already set up
  for FCM) and falls back to reCAPTCHA.

### Android

- `google-services.json` per flavor must contain a web OAuth client
  (`client_type: 3`); `google_sign_in` reads it from there.
- The app's **SHA-1 and SHA-256** fingerprints must be registered on the
  Firebase Android apps: debug, upload and **Play App Signing**. Without them
  Google sign-in fails (often reported as "cancelled") and phone sign-in
  answers `app-not-authorized`.

### Firebase console

Google, Apple and Phone providers enabled (they already are, for the web and
the Studio).

---

## Network layer

`lib/core/network/`, wired in `lib/core/di/core_providers.dart`.

- **`AuthInterceptor`** attaches `Authorization: Bearer <access token>` on
  routes in `ProtectedRoutes` (and optional ones when signed in).
- **`RetryInterceptor`** handles 401, and 403 on a request that went out
  without a bearer (FastAPI's `HTTPBearer` answers a missing header with
  403). It refreshes once, queues concurrent failures and replays them.
- **`AuthTokenApi`** uses its own bare Dio: a 401 from the exchange or the
  refresh is an answer, not a reason to refresh.

Observed backend responses: missing header → 403, invalid token → 401.

---

## Logout

`AuthNotifier.logout()`: unregister the push device and flush reader settings
while the token still works, flip state, clear the auth-scoped HTTP cache,
flush mala counts, settle pending prayer sends, `AuthService.localLogout()`
(tokens, guest flag, `currentUserId`, cached profile, sign-in method; forgets
the Google account so the next sign-in asks which one), clear the profile and
pending route, cancel notifications, reset analytics.

There is no server-side session to end: the backend's tokens simply stop
being used.

## State restoration

`AuthNotifier._runRestoreLoginState()` on launch:

1. First launch on Android clears any residual session (backups are off). iOS
   keeps the Keychain so a reinstall stays signed in.
2. `initialize` — the one-time Auth0 sign-out above.
3. `hasValidCredentials` — is a session stored? A `false` here is
   indeterminate (a failed keystore read looks the same), so it never logs
   anyone out by itself.
4. `getCredentials` — refreshes an expiring access token. A permanent failure
   falls through to the guest check; a transient one keeps the session and
   retries on the next request.

---

## Troubleshooting

### Google sign-in closes at once on Android, reported as cancelled
A configuration error: Credential Manager reports most of them as a cancel.
Check the SHA fingerprints for that build's signing key, and that
`google-services.json` has a `client_type: 3` entry.

### Phone sign-in fails with `app-not-authorized` or `missing-client-identifier`
Android: SHA-256 not registered. iOS: no APNs token and no reCAPTCHA URL
scheme — check `GOOGLE_REVERSED_CLIENT_ID` for the flavor.

### "Sign-in was refused (HTTP 401)" right after a successful provider sign-in
The exchange refused the Firebase token: the app is built against a different
Firebase project than the backend, or the device clock is wrong (the backend
checks the sign-in time).

### Everyone is logged out after N days
The refresh token expired; the backend does not renew it
(`REFRESH_TOKEN_EXPIRE_DAYS`).

### 401 loop
Should not happen: a refused refresh on the 401 path ends the session. If it
does, check that the failure reaches `RetryInterceptor.onAuthExpired`.
