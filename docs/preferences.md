# Khonager preferences

This is the compact, opinionated entry point for decisions that repeat across
khonager projects. It describes defaults, not immutable rules. Product needs and
intentional local decisions win.

## Product character

Khonager products should feel personal, capable, and a little distinctive
without becoming confusing. The usual goal is a useful tool or expressive
experience, not a generic dashboard or an engagement machine.

- Build one end-to-end useful flow before widening the product.
- Prefer local-first, privacy-first, and offline-capable behavior where the
  product can support it honestly.
- Give the user control over their data, visibility, integrations, AI provider,
  and destructive actions.
- Keep third-party services replaceable and make their failure states explicit.
- Prefer current real data and working integrations over convincing placeholders.
- State limitations plainly. Never present a prototype, deterministic fallback,
  debug build, or planned feature as something stronger.
- For recommendations and AI, explain why an answer fits. Use local execution by
  default when practical and retain a deterministic no-model path.
- Avoid addictive feed mechanics and artificial urgency unless they are part of
  the product's actual purpose.

## Visual character

The portfolio does not use one brand palette everywhere. It does repeat a visual
grammar:

- calm neutral foundations, commonly graphite/black or soft off-white;
- rounded, low-elevation surfaces with clear spacing;
- one product-specific accent and, when useful, one supporting accent;
- translucent glass, gradients, glow, or animated backgrounds used as atmosphere
  and identity rather than on every component;
- crisp sans-serif typography, usually the system family or Inter;
- familiar platform icons and controls before custom chrome;
- direct, spatial interaction with short, purposeful motion;
- responsive mobile, tablet, and desktop compositions rather than a stretched
  phone layout.

Dark-first is a recurring taste, especially for personal, media, communication,
and atmospheric products. It is not a requirement. Earthy, bright, or game-like
products should use a palette that fits their world while keeping the same
hierarchy and restraint.

See [`design-system.md`](design-system.md) for concrete tokens and rules.

## Engineering character

- Flutter is the default for a new cross-platform application when a native-feel
  Android/Linux/mobile experience matters.
- React, TypeScript, Vite, Tailwind, and shadcn/Radix are the established web-app
  combination. Use semantic design tokens rather than scattered utility values.
- Godot is the established choice for independent games. Keep game state and
  systems separate from scenes and presentation where practical.
- Nix flakes are the preferred reproducible development shell for non-trivial
  projects, especially Flutter/Android, Godot, Python, and native toolchains.
- Keep domain behavior independent from UI and vendor SDKs. Small prototypes may
  start flatter, but should gain boundaries before integrations multiply.
- Prefer typed boundaries, explicit data flow, real error states, and the
  cheapest meaningful tests.
- Pin toolchains, commit lockfiles, and make the same checks easy locally and in
  CI.
- Do not add a dependency, abstraction, backend, or state-management package only
  because another khonager project uses it.

## Delivery character

- `main` is the stable source line and `unstable` is the normal integration and
  development-build line.
- Stable versions use immutable SemVer tags; development builds are visibly
  distinct and installable alongside or safely upgradable to stable when the
  platform permits it.
- Android and Linux commonly receive first-class attention, while responsive
  and platform-isolated code should keep web, Windows, macOS, and iOS viable when
  they are in scope.
- Prefer direct/open distribution such as GitHub Releases, Obtainium, and F-Droid
  where it fits, while meeting app-store policy when stores are targeted.
- Release automation must fail closed when signing, version, or required
  configuration is missing.

## Writing and collaboration

- Use plain, concise language and concrete verbs.
- Lead documentation with what the project is, its current scope, and how to run
  it. Move history and exhaustive reference material lower.
- Document decisions, invariants, data flows, limitations, and exact verification
  commands. Avoid comments that merely narrate code.
- Iteration and `wip` branches/commits are normal during exploration. Before a
  stable merge, replace starter documentation, remove dead experiments, format
  the code, and verify the complete flow.
- A screenshot or sketch can establish visual truth. Keep the source reference,
  capture the built result, and record why a material design decision changed.

## Things not to cargo-cult

The portfolio also contains experiments, generated starters, old projects, and
forks. Their presence is not a preference. In particular:

- starter README text and unused starter CSS;
- raw colors duplicated throughout components;
- every dependency from a mature app copied into a small one;
- a specific backend chosen without considering the product's data model;
- per-title or per-example hard-coded AI/search knowledge;
- large all-purpose screens/services that grew during prototyping;
- visual effects added without reduced-motion, contrast, or performance checks.

When evidence is mixed, choose the simpler, more maintainable option and record
the local decision.
