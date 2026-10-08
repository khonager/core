# First-version verification

Verified locally on 2026-10-08 using Flutter 3.41.9 / Dart 3.11.5.

## Automated checks

- Catalog validation and generated asset/Android package-query consistency.
- Dart formatting and `flutter analyze` with no issues.
- 14 tests: stable/dev release selection, draft exclusion, stable fallback beyond
  the recent feed, multi-workflow failure aggregation, rate-limit errors, ETags,
  complete multi-job logs, missing-log errors, and authenticated redirects that
  do not forward credentials to the storage host.
- Widget flows: search, navigation, release-channel switching, notification
  sheet, offline errors, 390px phone / 1280px split layouts, and 200% text scaling.
- Golden images under `test/goldens` use deterministic test fixtures and Flutter's
  test font. They are regression checks, not screenshots of live GitHub data.
- Android debug build, Android release-mode development APKs, and web build.
- Nix flake development-shell evaluation; the entire SDK closure was not rebuilt.

## Rendered review

Live GitHub data was rendered in Chromium and Android API 35. Screenshots:

- [Phone library](screenshots/library-phone.png)
- [Phone project details](screenshots/details-phone.png)
- [Wide library/details](screenshots/library-wide.png)
- [Android library](screenshots/android-library.png)
- [Android downloaded APK](screenshots/android-download.png)
- [Android system installer](screenshots/android-installer.png)

The initial website repository is not public, so its status is neutral with an
access explanation in details. Other rows show actual current workflow status.
Trace uses a monogram because its existing launcher was still Flutter branding.

## Android smoke test

A separate temporary Android API 35 emulator was used; the user's existing AVD
was not modified. Verified app launch, live catalog/release loading, stable/dev
selection, actual Trans APK download (112.9 MB), measured transfer progress,
unknown-source permission handoff, and Android's real install confirmation.

Authenticated log access is covered by HTTP boundary tests, including credential
isolation on redirects. No personal GitHub credential was used during testing;
GitHub returned 403 for the unauthenticated live log endpoint. The app provides a
contextual token dialog and a browser fallback for this case.

This is not a production-release certification. Physical-device behavior,
private-asset downloads, OEM-specific installer/notification behavior, background
alerts, and stable signing remain outside the first-version verification scope.
