# Adopting Core

## New application

1. Write the product brief: user, problem, promise, non-goals, supported
   platforms, data flows, and business model.
2. Choose a permanent package/application ID before the first public build.
3. Choose a license after checking the licenses of shipped dependencies.
4. Copy the relevant files from `templates/flutter`.
5. Create `main` and `unstable`; protect `main` with pull requests and CI.
6. Generate a dedicated Android release key and back it up outside GitHub.
7. Add repository variables and secrets documented by the application.
8. Verify formatting, analysis, tests, an installable build, update signing, and
   the complete primary user flow before publishing.

## Existing application

Adopt one concern at a time. Start with secret hygiene and release signing,
then CI, version/tag rules, architecture boundaries, accessibility, and product
documentation. Record intentional exceptions in the application repository.

## Per-repository handoff

Copy `templates/AGENTS.md` to the repository root and replace its placeholders.
This gives coding agents the project-specific commands and points them back to
Core without requiring the same setup explanation in every session.

