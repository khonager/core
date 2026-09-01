# Product principles

- Name the user and problem before naming features.
- Keep one clear product promise and list explicit non-goals.
- Prefer a complete, trustworthy primary flow over a wide incomplete surface.
- Prefer useful tools and deliberate experiences over engagement loops. Do not
  add infinite feeds, artificial urgency, streak pressure, or noisy retention
  mechanics unless they are intrinsic to the product.
- Treat privacy, offline behavior, account ownership, export, and deletion as
  product behavior rather than policy-page details.
- Prefer local-first or on-device behavior when it is practical. Cloud sync is
  an enhancement, not an excuse to make basic local behavior fragile.
- Keep users in control of imports, permissions, AI, sharing, destructive
  actions, and public visibility. Privacy-sensitive choices default to the
  narrower audience.
- Distinguish facts, assumptions, and taste. Validate expensive assumptions
  early with users or working prototypes.
- Track known limitations honestly; do not market planned behavior as shipped.
- Give every third-party service a stated purpose, data flow, failure mode, and
  removal strategy.
- Make optional integrations degrade gracefully. A missing model, account,
  network, or provider should have an explicit fallback or an honest blocked
  state rather than a fake result.
- AI output must be identifiable, explainable in the product context, and
  replaceable by deterministic behavior where the primary flow depends on it.
  Do not send private content to a remote model without informed consent.
- Solve general retrieval and modeling problems generally. Do not accumulate
  title-specific aliases or one-off knowledge rules to make individual examples
  pass.

Each app should keep its concrete product brief and roadmap locally. Core holds
only principles shared across products.
