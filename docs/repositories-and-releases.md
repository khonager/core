# Repositories and releases

## Branches and versions

- `main` is always the stable source line.
- `unstable` integrates active development and produces development builds.
- Feature branches are short lived and merge through reviewed pull requests.
- `pubspec.yaml` is the source of the Flutter app version.
- Stable releases use immutable annotated `vMAJOR.MINOR.PATCH` tags.
- Development releases use `vMAJOR.MINOR.PATCH-dev.RUN` prerelease tags.
- Keep experiments and `wip` commits on short-lived or integration branches.
  Stable history and release notes should describe user-visible outcomes plainly.

## CI and permissions

- Run format, analysis, and tests on pull requests and long-lived branches.
- Pin Flutter and Java; use dependency caching and explicit artifact retention.
- Give each job the smallest GitHub token permissions it needs.
- Builds from untrusted pull requests never receive publishing credentials.
- Use repository variables for public configuration and secrets for credentials.
  A value embedded in a client app is recoverable even if CI stores it as a
  secret.
- Reuse Core's callable quality workflows when they fit, but keep signing,
  deployment, flavors, and smoke tests in the application that owns them.
- Verify a production build in addition to linting/tests. Upload expected
  artifacts with finite retention and fail if the artifact is absent.

## Mobile signing

- Generate a unique release key for each Android application.
- Back keys up outside the source repository and outside GitHub.
- Never publish a debug-signed app under the production application ID.
- Fail tagged builds when signing inputs are incomplete or absent.
- Keep the package ID and signing identity stable after the first public build.
- A separately installable development build must use its own application ID,
  display name, and update/signing lineage. Otherwise make the prerelease upgrade
  path and downgrade behavior explicit.

## Distribution and project presentation

- GitHub Releases are the normal direct-download source. Add an Obtainium link
  for Android when releases contain compatible APKs.
- F-Droid or a personal F-Droid repository is preferred when the app and its
  dependencies satisfy the channel's source and licensing expectations.
- Store releases, direct releases, web builds, and development channels should
  identify the same version and commit unambiguously.
- Release notes lead with user-visible changes, then compatibility, migration,
  and known limitations. Do not paste raw commit history as the final notes.
- Replace generated starter READMEs before sharing a project. A public README
  should state the product promise, current status, supported platforms, install
  and development paths, data-relevant integrations, limitations, and license.

## Public release gate

Before the first release, confirm branding, package IDs, permissions, license
compatibility, privacy disclosures, signing-key recovery, security contact,
upgrade behavior, and an end-to-end smoke test on a real target device.
