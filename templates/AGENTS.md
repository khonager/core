# Agent instructions

This project follows the shared principles in `khonager/core`. Read the relevant
Core product, design/UX, engineering, and release documents before making
material decisions. Local repository documentation wins when it intentionally
differs from Core.

## Project

- Product: `<one-sentence product promise>`
- Supported targets: `<platforms>`
- Stable branch: `main`
- Integration branch: `unstable`

## Required checks

Run these before handing off code changes:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Add the project-specific build or end-to-end verification commands here.

