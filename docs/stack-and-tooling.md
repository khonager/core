# Stack and tooling defaults

Choose the smallest stack that fits the product. These defaults reflect repeated
portfolio choices; they are not a mandate to rewrite a healthy existing project.

## Decision table

| Product shape | Default | Use it when | Avoid it when |
| --- | --- | --- | --- |
| Cross-platform application | Flutter/Dart | Android, Linux, mobile, or one shared native-feeling UI matters | A content-first website or tiny browser-only tool is the whole product |
| Browser application/PWA | React + TypeScript + Vite | Rich client interaction, Firebase/Supabase, mapping, dashboards, or installable PWA behavior matters | Static HTML and a small script would be enough |
| Web UI primitives | Tailwind + shadcn/Radix + Lucide | Accessible composable controls and semantic tokens speed delivery | The framework/platform already supplies the needed native controls |
| Independent game | Godot 4 | Scene-based 2D/3D game development and fast iteration | The project is a mod bound to another engine/runtime |
| Native/game mod | Host SDK and its language | The target game/runtime dictates Unity, C#, Kotlin, or another toolchain | A portable layer can own domain behavior instead |
| Small service or hardware lab | Python with typed boundaries | Fast experiments, device validation, ONNX, or a compact API | The service belongs inside an existing typed backend and gains nothing from another runtime |

Electron is acceptable for a desktop project tied to a web/Steam runtime, but it
is not the default for a new general-purpose cross-platform app while Flutter is
a good fit.

## Reproducible development

- Add a `flake.nix` for projects whose SDKs, native libraries, Android tools, game
  engine, or deployment CLIs are not trivial.
- Pin `nixpkgs` intentionally and commit `flake.lock`.
- The default shell should expose the normal entry commands and set only the
  environment needed by the repository.
- Keep local and CI versions aligned: Flutter, Dart, Java, Android SDK, Node,
  package manager, Godot, Python, Rust, and native libraries as applicable.
- Document a non-Nix route when outside contributors or hosted builders need it.

## Flutter applications

Defaults:

- Material 3 unless the product deliberately needs a custom/legacy rendering
  model.
- `ThemeData` + `ColorScheme` + a focused `ThemeExtension` for semantic roles.
- `flutter_localizations`/ARB when the app has user-facing copy beyond a narrow
  prototype.
- platform capability interfaces with IO/web/stub implementations where APIs
  differ.
- secure storage for credentials, ordinary preferences only for non-sensitive
  settings, and explicit migrations for persisted models.

Suggested shape once an app grows beyond one screen:

```text
lib/
  app/                 composition, navigation, application shell
  core/                shared domain types, policies, ports, theme
  features/<feature>/  presentation + application behavior for one capability
  infrastructure/      Firebase, Supabase, HTTP, database, SDK, platform adapters
```

Small applications may use `models`, `services`, `views`, and `widgets`, but do
not let screens directly become the permanent integration layer. Provider is an
established lightweight option; retain an existing state solution when it works
and add a package only when lifecycle or data-flow needs justify it.

Minimum checks:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Add a real target build and critical-flow smoke test for release-facing changes.

## React web applications

Defaults:

- TypeScript in strict mode; React function components; Vite for client apps.
- shared semantic tokens in the global theme, consumed through Tailwind aliases;
- shadcn/Radix primitives composed locally rather than edited into unrelated
  one-off variants;
- `class-variance-authority`, `clsx`, and `tailwind-merge` for controlled
  component variants where already present;
- Zod or an equivalent schema at untyped network/storage boundaries;
- TanStack Query for meaningful server-state caching, not for local component
  state;
- React Hook Form for non-trivial forms, not every two-field interaction;
- Lucide icons with accessible labels.

Remove Vite starter CSS, logos, copy, and README content immediately. A project
is not ready for handoff while generated starter material still describes it.

Minimum scripts should cover development, type-aware linting, tests when behavior
exists, and a production build. CI must run the production build because it
catches failures that a dev server does not.

## Games and mods

- Keep input, state, combat/economy rules, and save formats separate from visual
  scenes or engine callbacks enough to test deterministic behavior.
- Prefer authored, licensed assets and record provenance in third-party notices.
- Make controls, comfort, accessibility, performance budgets, and debug options
  explicit—especially for VR.
- Build effect/audio systems around stable cue identifiers and replaceable
  assets so polish does not require rewriting gameplay.
- Treat placeholder or generated art as provisional and keep source assets
  separate from generated/imported engine artifacts.

## Data and backends

Firebase is the recurring default for authentication, hosted data, functions,
and web deployment in account-based products. Supabase is also established and
should remain where its relational/realtime model already fits. Choose based on
the data and operational model, not portfolio frequency.

For either:

- put vendor SDKs behind application-facing services/ports;
- define ownership and authorization in server rules, not only the UI;
- separate dev/staging/prod configuration;
- document public client identifiers versus actual credentials;
- support deletion/export appropriate to the product;
- test offline, retry, conflict, and partial-success behavior;
- never claim client-side configuration is secret because CI stored it as one.

## AI and recommendation features

- On-device or user-controlled local execution is the preferred default when
  viable.
- Offer explicit provider modes rather than silently switching data destinations.
- Fetch current catalog/service data through ordinary APIs and give the model
  structured context; do not expect model memory to be the database.
- Validate model output into typed intent and retain the user's explicit choices
  separately from inferred choices.
- Keep deterministic ranking, parsing, or summaries as a no-model/error fallback.
- Improve prompts, grounding, retrieval, observability, and benchmark coverage
  instead of adding example-specific knowledge maps.

## Dependency and code hygiene

- Commit lockfiles and source configuration; ignore generated outputs, caches,
  credentials, keystores, and local environment files.
- Prefer narrow adapters over global singletons and implicit initialization.
- Name files and types by domain meaning. Generic `utils` and `helpers` are a
  last resort, not the first folder.
- Comments explain constraints and surprising decisions. Delete stale TODOs or
  connect them to a tracked decision.
- Do not edit generated platform/configuration files without also identifying
  their source of truth.
