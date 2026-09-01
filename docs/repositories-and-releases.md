# Repositories and releases

## Branches and versions

- `main` is always the stable source line.
- `unstable` integrates active development and produces development builds.
- Feature branches are short lived and merge through reviewed pull requests.
- `pubspec.yaml` is the source of the Flutter app version.
- Stable releases use immutable annotated `vMAJOR.MINOR.PATCH` tags.
- Development releases use `vMAJOR.MINOR.PATCH-dev.RUN` prerelease tags.

## CI and permissions

- Run format, analysis, and tests on pull requests and long-lived branches.
- Pin Flutter and Java; use dependency caching and explicit artifact retention.
- Give each job the smallest GitHub token permissions it needs.
- Builds from untrusted pull requests never receive publishing credentials.
- Use repository variables for public configuration and secrets for credentials.
  A value embedded in a client app is recoverable even if CI stores it as a
  secret.

## Mobile signing

- Generate a unique release key for each Android application.
- Back keys up outside the source repository and outside GitHub.
- Never publish a debug-signed app under the production application ID.
- Fail tagged builds when signing inputs are incomplete or absent.
- Keep the package ID and signing identity stable after the first public build.

## Public release gate

Before the first release, confirm branding, package IDs, permissions, license
compatibility, privacy disclosures, signing-key recovery, security contact,
upgrade behavior, and an end-to-end smoke test on a real target device.

