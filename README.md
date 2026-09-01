# Core

Core is the shared reference for khonager applications. It records the product,
design, UX, engineering, repository, and release decisions that should not need
to be rediscovered for every new project.

Core is a baseline, not a framework. Applications may diverge when their users
or platforms require it, but the reason should be written down in that
application's repository.

## Start here

- [`docs/product.md`](docs/product.md) — product scope and decision principles
- [`docs/design-ux.md`](docs/design-ux.md) — interface, accessibility, and flow
  principles
- [`docs/engineering.md`](docs/engineering.md) — code and architecture baseline
- [`docs/repositories-and-releases.md`](docs/repositories-and-releases.md) —
  branches, CI, signing, tags, and public releases
- [`ADOPTING.md`](ADOPTING.md) — checklist for a new or existing application
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

## Status and license

This is an initial personal baseline. Its license has intentionally not been
selected yet. Until a license is added, the repository is publicly readable but
does not grant general reuse rights. Choose a license before inviting external
reuse or contributions.

