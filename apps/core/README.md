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
CI builds the same development artifact without publishing a release.

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

The initial catalog contains Trans, TypeSync, Trace, Majika, and khonager.de.
The website's portfolio repository is not publicly accessible at the time of
verification; its website works, and its build panel reports unavailable access.

## Data and limitations

No Core server, account, analytics, or rating service. GitHub receives API
requests from the device and applies its rate limits. Public browsing needs no
credentials. Restricted logs can use an optional fine-grained personal access
token with Actions: read permission for selected repositories. Use Connect GitHub
inside project details, or the dialog shown when a log needs access. Android
stores the token using `flutter_secure_storage`; the web preview holds it only in
memory until reload. Disconnect from the same dialog to delete the token and
clear account-dependent cached metadata. Tokens are never forwarded to signed
log-download storage URLs. Android backup is disabled.

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
