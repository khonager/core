# Core app

An Android-first home for khonager apps and websites, built in Flutter 3.47.0
(the version pinned by the Nix development shell). Core's reference documentation
and templates remain in this repository.

## Run

From the repository root, enter `nix develop` (the committed lock pins Nixpkgs).
The shell provides Flutter 3.47.0, Java 17, and the required Android SDK/NDK.
The root `./core` command runs Flutter inside `apps/core`, so you can stay at the
repository root:

```sh
python3 scripts/sync_catalog.py
./core pub get
./core run
```

For a browser preview: `./core run -d chrome`. The web target is a design and
catalog preview; installing/uninstalling apps and notifications require Android.

### Linux desktop

On a Linux laptop with a graphical session, run from the repository root:

```sh
nix develop
./core pub get
./core run -d linux
```

Choose a project, then use **Build activity → Copy full log** on a completed
workflow run. The app copies all available job logs for that run to the system
clipboard; paste them into an editor or issue. The build card also opens the run
on GitHub. If a log needs access, use **Manage GitHub access** in project details
to connect a fine-grained token with **Actions: read** permission. Linux saves
it in the desktop Secret Service keyring (such as GNOME Keyring or KWallet).
You can disconnect there to remove it. Public logs work without a token.

The Linux target shows the catalog, releases, and build activity. APK downloads
open in a browser; installing apps and notifications still require Android.
`./core build linux` writes a bundle under `apps/core/build/linux/x64/release/bundle/`.

```sh
dart format --output=none --set-exit-if-changed apps/core/lib apps/core/test
./core analyze
./core test
./core build apk --release --split-per-abi --target-platform android-arm64,android-x64
./core build appbundle
./core build web --no-web-resources-cdn
```

Use `apps/core/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` on modern
Android phones; `app-x86_64-release.apk` is for x86 emulators. The release compiler
reduces size, but this is still a
**development build**, labeled **Core Dev**, with package ID `dev.khonager.core.dev`
and a development signing key. Do not treat it as a production signing identity.
CI uploads these disposable APKs as workflow artifacts. They cannot reliably
update one another because each runner may use a different debug key.

### Publish an installable Core development build

Create and back up a dedicated Android development keystore. Set these GitHub
Actions repository secrets: `CORE_DEV_KEYSTORE_BASE64` (base64 of the keystore
file), `CORE_DEV_STORE_PASSWORD`, `CORE_DEV_KEY_ALIAS`, and
`CORE_DEV_KEY_PASSWORD`. Keep the same key for every Core development release;
losing it prevents updates over existing installations.

Push an annotated tag matching the `pubspec.yaml` version, such as
`v0.1.0-dev.1`. The Core app workflow checks the tag and signing inputs, tests
and builds Core, then publishes the ARM64 and x86_64 APKs as a GitHub
prerelease. Its Android build number comes from the workflow run number, so a
later release can update an earlier one. Core lists this prerelease in its own
project details; choose the APK for your device to install or update Core.
The first CI-signed build cannot update a locally installed debug-signed Core or
one signed by another development key. Download the release APK to your browser's
Downloads folder first, then uninstall Core Dev and install that downloaded APK.
Uninstalling clears Core's saved settings and GitHub sign-in; the APK downloaded
inside Core is also removed with the app. Future builds signed with the same
development key can update in place. Stable Core releases and a production
signing identity have not been configured yet.

## First version

- Searchable curated Library and Project details; releases are inside details.
- A recent-commits list at the bottom of each project's details page. Entries
  open on GitHub; commits are fetched when details open and cached locally.
- Warm eggshell surface, large rounded icons, subdued descriptions.
- GitHub stable/prerelease data and Markdown changelogs. Stable releases are
  recovered through the latest endpoint when absent from the recent release feed;
  development releases are found by paging through published releases.
- Latest workflow runs, condensed status separators, links to GitHub Actions.
  Build cards show GitHub Actions step progress, the running or failed step, and
  time estimates from the previous successful run of the same workflow.
  Red means any tracked workflow failed; orange means one is still running;
  green means all tracked workflows passed. Cancelled/missing/unavailable data
  is neutral, never falsely green. The first 30 recent runs define the tracked
  workflow set; older inactive workflows may not appear.
- Copy every available job log in a build using Copy full log or long-pressing
  its build card. Expired/restricted/incomplete logs show a useful error; partial
  logs are not silently reported as complete.
- Android APK asset selection, DownloadManager progress, cancellation, retry,
  system install/unknown-source permission handoff, installed version detection,
  and system-confirmed uninstall. A blue separator shows transfer state.
  Downloads survive app restarts. APK package IDs are checked against the
  catalog before handing off to Android's signature/compatibility checks.
- Per-project notification switches, persisted on-device. Alerts are emitted
  for new changes detected when opening a project or refreshing the library,
  after an initial baseline. **No background notification polling or server push
  yet.**
- Cached releases and runs; refresh failures preserve saved data and report the
  error in details. Pull to refresh or use the refresh button.
- On Android, website links use Custom Tabs; other platforms use a browser.
- A side-by-side library/detail layout at wide widths. No ratings, Settings page,
  Sandbox, or Gallery in this version.

## Curating

Edit [`../../catalog/projects.json`](../../catalog/projects.json), then run
`python3 scripts/sync_catalog.py`. It validates the data and updates both the
bundled asset and Android's explicit package-visibility queries. CI checks that
these generated outputs agree. Catalog edits ship with a new Core build for now.

`packageId` identifies the stable Android app. Set `devPackageId` when a dev APK
uses a separate ID; otherwise Core checks against the stable package ID. All
listed APKs are offered with their filenames; users choose their architecture.
Android performs final signing, version, and device-compatibility validation.
Core does not silently replace apps or bypass Android prompts. CI artifacts,
split-APK bundles, and background auto-updates are not supported. Private
GitHub release APKs can be installed on Android after connecting GitHub access.

The catalog includes the owner's apps and verified websites. Riverfold's signed
tag builds publish `riverfold.apk` as a stable GitHub Release; its branch builds
are workflow artifacts and do not appear as installable releases. App entries can
also link to their websites; standalone sites such as Files and Karma Tracker
have their own entries. Some repositories are private, so public browsing may
show unavailable release and build data for those entries.

## Data and limitations

No Core server, Core account, analytics, or rating service. GitHub receives API
requests from the device and applies its rate limits. Public browsing needs no
credentials. Private releases and restricted logs can use a fine-grained
personal access token for selected repositories. Give it **Contents: read** for
releases and **Actions: read** for build activity and logs. Friends need their
own GitHub access to each private repository before a token or sign-in can read
it. Open any project and choose **Connect GitHub token**. Android and Linux
store the token using `flutter_secure_storage`; the web preview holds it only in
memory until reload. Disconnect from Manage GitHub access to delete the token and
clear account-dependent cached metadata. Tokens are never forwarded to signed
log-download storage URLs. Android backup is disabled.

Core shows saved release and build data at launch and fetches fresh metadata
when a project page opens. A full library refresh is still available, but stops
early when the anonymous GitHub allowance runs low. Core reserves the final five
anonymous API requests and remembers GitHub's reset time across restarts. The
allowance is shared by devices on the same public IP address. Authenticated
GitHub access has a larger per-user allowance.

While a project page is open, active build steps update every ten minutes
without GitHub access or every two minutes when connected. The build refresh
button checks immediately. Core reuses the previous successful run during
polling. Progress is based on completed GitHub Actions steps, and time estimates
use that previous run of the same workflow. Estimates are unavailable until
that history exists.

### Optional GitHub sign-in

Core never prompts for sign-in during normal browsing. In an Android build with
GitHub sign-in configured, a rate-limit notice can be tapped to start sign-in.
The user copies a short code, approves Core on GitHub, and Core resumes with an
authenticated API allowance. Android stores the access and refresh tokens in
secure storage and refreshes expiring access automatically. Disconnect through
Manage GitHub access in project details. The web preview has no sign-in flow.

To configure this for builds:

1. Register a GitHub App under the account that will own Core. Give it read-only
   **Actions** and **Contents** repository permissions. Disable webhooks, and
   enable **Device Flow** under **Identifying and authorizing users**. No client
   secret or callback endpoint is used by Core.
2. Copy the app's **Client ID** (not its App ID or client secret) to the GitHub
   Actions repository variable `CORE_GITHUB_CLIENT_ID`. CI passes it to Android
   builds as `GITHUB_CLIENT_ID`. For a local build, pass
   `--dart-define=GITHUB_CLIENT_ID=Iv1.YOUR_CLIENT_ID` to `flutter run` or
   `flutter build apk`.

Without that client ID, the sign-in action is hidden; connecting a fine-grained
token still works. To read private repositories through GitHub App sign-in, the
app must also be installed on those repositories and the signed-in user must
have access. Each friend sees only repositories allowed by both their GitHub
permissions and the app installation.

Core stores release/build metadata and notification preferences locally. GitHub
access also allows reading private metadata and downloading private release
APKs. Core requests the APK through GitHub's authenticated API and passes only
the short-lived GitHub asset URL to Android's DownloadManager. Expired logs remain
unavailable even with a token. Large logs are loaded into memory for copying;
web previews may encounter cross-origin limits. No OAuth client registration or
backend is required for the token flow.

Android stores downloads in Core's own external-files directory. Cancel/dismiss
removes the associated download; successful installation clears it. Uninstalling
Core removes its local data. Notification delivery still depends on Android
permission and channel settings. Phone app settings remain the settings surface.

## Design and verification

See [PROJECT.md](PROJECT.md) for the agreed scope and
[docs/verification.md](docs/verification.md) for checks and screenshots.
Project icons in `assets/icons` were copied from the owner's corresponding
local project launchers; see [docs/assets.md](docs/assets.md). Core's temporary
ring mark is a simple vector, pending the user's final branding.

The repository has not selected a license; see the root README.

## Nix Android SDK troubleshooting

After changing `flake.nix`, exit and re-enter `nix develop` so `ANDROID_HOME` and
`ANDROID_SDK_ROOT` point to the new SDK. It includes platforms 35 and 36: the
app uses 36, while `jni_flutter` requests 35. A missing platform otherwise makes
Gradle attempt an installation into the read-only Nix store. Do not run
`sdkmanager` against that store path or try to make it writable.

Use the shell's Flutter 3.47.0 consistently; a system Flutter version may differ.
The existing AGP 8 / Kotlin compatibility flags remain intentional while the
plugin graph uses the legacy Kotlin Gradle plugin. Flutter's deprecation
warnings for those versions are not the missing-SDK build failure.
