# Project decisions

Keep this file short and replace every placeholder. It records only decisions
that specialize or intentionally override `khonager/core`; do not duplicate the
shared guides.

## Product

- **User:** `<who has the problem>`
- **Problem:** `<specific problem or desire>`
- **Promise:** `<one sentence describing the value>`
- **Primary flow:** `<entry -> key action -> useful result>`
- **Non-goals:** `<what this version deliberately does not do>`
- **Current status:** `<prototype | alpha | beta | stable>`
- **Supported targets:** `<platforms and priority>`

## Data and trust

- **Posture:** `<local-only | local-first | synced | online-only>`
- **Sensitive data:** `<what it is and where it lives>`
- **Third parties:** `<service -> purpose -> data sent -> failure behavior>`
- **Export/deletion:** `<user-visible behavior>`
- **AI:** `<none, local, optional remote; consent and fallback>`

## Design

- **Mood:** `<three to five useful adjectives>`
- **Theme:** `<system | light/dark | deliberate single theme>`
- **Accent:** `<semantic name and value; supporting accent if any>`
- **Typography:** `<system/Inter/product family>`
- **Density:** `<comfortable | compact | immersive>`
- **Narrow navigation:** `<model>`
- **Wide navigation:** `<model>`
- **Effects:** `<where glass, gradient, glow, imagery, and motion are allowed>`
- **Core exceptions:** `<intentional differences from docs/design-system.md>`

## Engineering

- **Stack:** `<frameworks and runtimes>`
- **Architecture:** `<dependency direction and main boundaries>`
- **Persistence:** `<local and remote stores>`
- **Configuration:** `<public variables and secrets; never include values>`
- **Development:** `<nix develop or setup command>`
- **Required checks:** `<format, lint/analyze, tests, builds, smoke flow>`

## Delivery

- **Stable branch:** `main`
- **Integration branch:** `unstable`
- **Version source:** `<file>`
- **Channels:** `<store, F-Droid, Obtainium, web, other>`
- **Signing/recovery owner:** `<location/owner, never the secret>`

## Decision log

Add only material deviations that a future contributor could otherwise mistake
for an accident.

| Date | Decision | Reason | Revisit when |
| --- | --- | --- | --- |
| `<YYYY-MM-DD>` | `<decision>` | `<evidence or constraint>` | `<trigger>` |
