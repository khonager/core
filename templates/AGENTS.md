# Agent instructions

This project follows the shared principles in `khonager/core`. Read the relevant
Core preferences, product, design system, design/UX, engineering, stack, and
release documents before making material decisions. Local repository
documentation wins when it intentionally differs from Core.

## Project

- Product: `<one-sentence product promise>`
- Supported targets: `<platforms>`
- Primary user flow: `<start -> value -> completion>`
- Data posture: `<local-only | local-first | synced | online-only>`
- Visual direction: `<mood, product accent, light/dark behavior>`
- Stable branch: `main`
- Integration branch: `unstable`

## Change rules

- Preserve the product's established visual language and semantic tokens. Do
  not introduce raw one-off colors, spacing values, or a second component style
  when an existing token or component can express the change.
- Keep product logic out of widgets/components and third-party SDK types out of
  domain code.
- Define loading, empty, error, offline, permission, and partial-success behavior
  for any changed primary flow.
- Do not describe planned behavior as shipped. Update local documentation when
  a material product, architecture, data-flow, or design decision changes.
- For visual changes, inspect the rendered result at narrow and wide sizes and
  attach or record screenshots when the change is material.

## Required checks

Run these before handing off code changes:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Add the project-specific build or end-to-end verification commands here.
