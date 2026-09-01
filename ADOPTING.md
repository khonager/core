# Adopting Core

## New application

1. Write the product brief: user, problem, promise, non-goals, supported
   platforms, data flows, and business model. Start from
   [`templates/PROJECT.md`](templates/PROJECT.md).
2. Record a one-page local design decision: visual mood, light/dark support,
   product accent, type choice, density, responsive structure, and any deliberate
   exception to `docs/design-system.md`.
3. Select the smallest fitting stack from `docs/stack-and-tooling.md` and create
   a reproducible development environment when the toolchain is non-trivial.
4. Choose a permanent package/application ID before the first public build.
5. Choose a license after checking the licenses of shipped dependencies and
   assets.
6. Copy and adapt the relevant files from `templates`.
7. Create `main` and `unstable`; protect `main` with pull requests and CI.
8. Generate a dedicated Android release key and back it up outside GitHub.
9. Add repository variables and secrets documented by the application.
10. Verify formatting, analysis, tests, an installable build, update signing, and
   the complete primary user flow before publishing.

## Existing application

Adopt one concern at a time. Start with secret hygiene and release signing,
then CI, version/tag rules, architecture boundaries, accessibility, and product
documentation. For visual work, replace raw colors and repeated spacing with
semantic tokens before attempting a complete redesign. Record intentional
exceptions in the application repository.

## Per-repository handoff

Copy [`templates/AGENTS.md`](templates/AGENTS.md) to the repository root and
replace its placeholders.
This gives coding agents the project-specific commands and points them back to
Core without requiring the same setup explanation in every session.
