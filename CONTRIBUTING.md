# Contributing

## Versioning (automatic — don't edit the version by hand)

CI bumps the app version from your **commit messages** / **branch names**:

| Bump | Commit starts with | or branch named |
| --- | --- | --- |
| **major** (`3.0.0`) | `feat!:` · `fix!:` · a `BREAKING CHANGE:` footer | `breaking/…` · `major/…` |
| **minor** (`2.10.0`) | `feat:` | `feat/…` · `feature/…` |
| **patch** (`2.9.3`) | anything else (`fix:`, `chore:`, …) | anything else |

**No convention → patch.** That's the only rule you need.

### How a change reaches users

There is one app, `org.pecha.app`. Which server a build talks to is picked by
its entry file (always `--flavor prod`):

| Server | Entry file | When |
| --- | --- | --- |
| dev | `lib/main_dev.dart` | on your computer |
| testing | `lib/main_staging.dart` | merge to `main` → TestFlight + Play internal |
| prod | `lib/main_prod.dart` | push a `vX.Y.Z` tag → App Store + Play production |

1. Merge to **`develop`**: tests only, no app build.
2. Merge `develop` into **`main`**: CI bumps the version (commits it to `main`),
   builds against the **testing** server and uploads to TestFlight and the Play
   internal track. Several merges before a release keep the same pending
   version; it only goes up when a bigger change lands.
3. When testing passes, tag **the commit CI built**. The run summary of the
   testing build prints the exact commands:

   ```sh
   git fetch origin
   git tag -a v2.48.0 <commit> -m "What's new in this version"
   git push origin v2.48.0
   ```

   The tag must be annotated, match the version in `pubspec.yaml` at that
   commit, and be on `main`, or the release stops before building. Its message
   (500 characters at most, Google Play's limit) becomes the "What's New" text
   in both stores and the GitHub Release.
4. The tag build talks to the **prod** server. It is sent to App Store review
   and released automatically once Apple approves it, and goes to Google Play
   production for 100% of users.
