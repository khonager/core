# Engineering principles

- Keep domain behavior independent from UI, storage, network, and platform SDKs.
- Put unstable integrations behind small interfaces with replaceable adapters.
- Prefer simple explicit data flow over hidden global state.
- Validate data at trust boundaries and use typed internal representations.
- Make cancellation, retry, timeout, partial failure, and idempotency deliberate.
- Store the minimum sensitive data and never log credentials or private content.
- Add tests at the cheapest layer that proves the behavior; reserve end-to-end
  tests for critical cross-boundary stories.
- Pin build toolchains, commit lockfiles, and automate format/analyze/test checks.
- Keep generated files generated and verify their source-of-truth artifacts.
- Optimize after measurement, while avoiding obviously unbounded work.
- Prefer a reproducible `nix develop` environment for projects with non-trivial
  toolchains. Pin the language/runtime and platform SDK versions used by CI.
- Keep platform-specific code behind narrow adapters and pair implementations
  with an explicit unsupported/stub path when a target lacks the capability.
- Organize growing applications by domain/feature and dependency direction,
  not by a single folder containing every screen, service, or widget.
- Keep application composition near the edge. Domain models and policies should
  be testable without starting Flutter, a browser, Firebase, or a game engine.
- Choose dependencies for a concrete capability. Do not copy the full dependency
  set of an older application into a new one.
- Treat offline, synchronization, migrations, conflicts, and version
  compatibility as domain behavior with tests, not UI edge cases.
- Keep a deterministic path around optional AI behavior. Validate structured AI
  output at the boundary and log diagnostics without private prompt content.

Documentation should explain decisions, invariants, and operating constraints.
Code comments should explain why surprising code is necessary.

Stack-specific defaults are documented in
[`stack-and-tooling.md`](stack-and-tooling.md).
