# Core app

An Android-first home for khonager apps and websites, built in Flutter 3.47.0
(the version pinned by the Nix development shell). Core's reference documentation
and templates remain in this repository.

## Run

From the repository root, optionally enter `nix develop` (the committed lock pins
Nixpkgs). Otherwise install Flutter 3.47.0, Java 17, and Android SDK/NDK components
required by Flutter, then run `flutter doctor` to check the toolchain.

```sh
python3 scripts/sync_catalog.py
cd apps/core
flutter pub get
flutter run
```

For a browser preview: `flutter run -d chrome`. The web target is a design and
catalog preview; installing/uninstalling apps and notifications require Android.

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64
flutter build appbundle
flutter build web --no-web-resources-cdn
```

Use `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` on modern Android
phones; `app-x86_64-release.apk` is for x86 emulators. The release compiler reduces
size, but this is still a
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
The first CI-signed build cannot update a locally installed debug-signed Core;
uninstall that local build first. Stable Core releases and a production signing
identity have not been configured yet.

## First version

- Searchable curated Library and Project details; releases are inside details.
- Warm eggshell surface, large rounded icons, subdued descriptions.
- GitHub stable/prerelease data and Markdown changelogs. Stable releases are
  recovered through the latest endpoint when absent from the recent release feed;
  development releases are found by paging through published releases.
- Latest workflow runs, condensed status separators, links to GitHub Actions.
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
  for new changes detected on opening/refreshing Core, after an initial baseline.
  **No scheduled background polling or server push yet.**
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
private releases, split-APK bundles, and background auto-updates are not supported.

The catalog contains Core, Trans, TypeSync, Trace, Majika, and khonager.de.
The website's portfolio repository is not publicly accessible at the time of
verification; its website works, and its build panel reports unavailable access.

## Data and limitations

No Core server, Core account, analytics, or rating service. GitHub receives API
requests from the device and applies its rate limits. Public browsing needs no
credentials. Restricted logs can use an optional fine-grained personal access
token with Actions: read permission for selected repositories. The token dialog
appears when a user requests a restricted log. Android
stores the token using `flutter_secure_storage`; the web preview holds it only in
memory until reload. Disconnect from Manage GitHub access to delete the token and
clear account-dependent cached metadata. Tokens are never forwarded to signed
log-download storage URLs. Android backup is disabled.

Core reuses saved release and build data for 30 minutes on launch and allows an
explicit refresh every two minutes. It remembers GitHub's rate-limit reset time
across app restarts and pauses requests until then. This reduces anonymous API
traffic but does not guarantee availability on networks where many users share
one IP address. Authenticated GitHub access has a larger per-user allowance.

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

Without that client ID, the sign-in action is hidden and public browsing keeps
working. To read private repositories through GitHub App access, the app must
also be installed on those repositories and the signed-in user must have access.

Core stores release/build metadata and notification preferences locally. GitHub
access also allows reading private metadata, but private APK downloads are not
yet supported by the Android DownloadManager integration. Expired logs remain
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
