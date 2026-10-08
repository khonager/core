# Core

Core is the shared reference for khonager applications. It records the product,
design, UX, engineering, repository, and release decisions that should not need
to be rediscovered for every new project.

Core is a baseline and decision record, and now also hosts the Android-first
[Core app](apps/core/README.md): a curated app/website library with GitHub build
activity and release downloads. The reference documents remain independently
useful; applications do not need a Core package dependency.
Applications may diverge when their users, genre, or platforms require it, but
the reason should be written down in that application's repository.

The baseline was inferred from the existing khonager project portfolio rather
than invented as a generic best-practices list. [`docs/portfolio-audit.md`](docs/portfolio-audit.md)
records the evidence and confidence of those inferences.

## Core app

The first development version lives in [`apps/core`](apps/core/README.md).
Edit [`catalog/projects.json`](catalog/projects.json) to curate the library.
See the app README for running, building, and current limitations.

## Start here

- [`docs/product.md`](docs/product.md) — product scope and decision principles
- [`docs/preferences.md`](docs/preferences.md) — the short version of how
  khonager products should feel and be built
- [`docs/design-system.md`](docs/design-system.md) — reusable visual language,
  tokens, layout, components, and motion
- [`docs/design-ux.md`](docs/design-ux.md) — interaction, accessibility, and
  complete-flow principles
- [`docs/engineering.md`](docs/engineering.md) — code and architecture baseline
- [`docs/stack-and-tooling.md`](docs/stack-and-tooling.md) — preferred stacks and
  project shapes
- [`docs/repositories-and-releases.md`](docs/repositories-and-releases.md) —
  branches, CI, signing, tags, and public releases
- [`ADOPTING.md`](ADOPTING.md) — checklist for a new or existing application
- [`templates/PROJECT.md`](templates/PROJECT.md) — copyable local product,
  design, architecture, and delivery decision record
- [`templates/flutter`](templates/flutter) — copyable Flutter project files

The reusable Flutter quality workflow can be called from another public
repository:

```yaml
jobs:
  quality:
    uses: khonager/core/.github/workflows/flutter-quality.yml@main
    with:
      flutter-version: "3.41.9"
```

Pin callers to a Core version tag once the first stable Core baseline is tagged.

## How to interpret Core

Use this order when instructions disagree:

1. Safety, legal, platform, and user requirements.
2. An intentional decision documented in the application repository.
3. The shared defaults in Core.
4. Existing local code where no decision has been recorded.

Core uses **must** for a requirement, **should** for the normal default, and
**may** for an option. Do not copy an old project quirk merely because it exists;
prefer the clearest current pattern described here.

## Status and license

This is an initial personal baseline. Its license has intentionally not been
selected yet. Until a license is added, the repository is publicly readable but
does not grant general reuse rights. Choose a license before inviting external
reuse or contributions.
