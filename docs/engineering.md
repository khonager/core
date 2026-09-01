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

Documentation should explain decisions, invariants, and operating constraints.
Code comments should explain why surprising code is necessary.

