# Portfolio audit

Last audited: 2026-09-01.

Core's opinionated defaults were inferred from the projects available in the
shared `personal` GitHub workspace and the public `khonager` account inventory.
This file preserves provenance so a future update can distinguish a repeated
preference from a generic recommendation or an inherited template.

## Evidence weighting

1. **Strong:** active original products with substantial khonager-authored code,
   documentation, design iterations, tests, and release history.
2. **Supporting:** prototypes, games, infrastructure, asset repositories, and
   smaller utilities that confirm a pattern but solve a different kind of
   problem.
3. **Weak/excluded:** forks, upstream code, generated starters, vendored assets,
   build outputs, and inactive experiments. These may show interests or required
   ecosystems, but do not define the shared style by themselves.

## Surveyed projects

Strong product/design/engineering evidence came from Maji, Majika, Trace, Trans,
TypeSync, dreamcord, friend-compass, karma-tracker, khonager, originguessr,
portofolio, roid, and the public `infamous` mod repository.

Supporting evidence came from Riverfold, ShadowStrikeArena, VisualNovel, bo3-vr,
gram, f-droid, Mondlicons, nixos, nixos-secrets, pantheon, teros,
framework-npu-lab, and osmosis-steam.

Motomeru, the external nix-config checkout, and plymouth-themes were reviewed as
fork/reference material and given little or no weight for personal preferences.
Public account forks that were not present locally were inventoried but not used
as design evidence. Private repositories were represented only when available
in the shared workspace.

## High-confidence findings

- Flutter is the dominant application stack; Android and Linux repeatedly
  receive explicit attention, with wider cross-platform support kept viable.
- Reproducible Nix development shells occur across mobile, game, web, Python,
  system, and native projects.
- Privacy-first/local-first behavior, user control, honest limitations, and
  deterministic fallback paths recur in the most deeply documented products.
- Active application repositories repeatedly separate stable and development
  delivery, automate builds, and publish through direct/open channels.
- Dark neutral surfaces, rounded cards, product accents, responsive structure,
  and selective glass/gradient/glow effects recur across independently designed
  UIs.
- Domain/service boundaries and platform adapters become more explicit as
  products mature; Trace, Majika, Maji, and TypeSync provide the clearest
  examples.

## Medium-confidence findings

- Inter or a system sans-serif is the preferred application typography.
- Firebase is the most common hosted backend/deployment choice, while Supabase
  remains an intentional fit for Trans. Core therefore treats Firebase as a
  familiar default, not a mandatory platform.
- Provider is a familiar lightweight Flutter state tool, but portfolio usage is
  not consistent enough to prescribe one state-management package.
- Vite, React, TypeScript, Tailwind, shadcn/Radix, and Lucide form the recurring
  rich-web stack, though several projects began from the same generated starter
  and were discounted accordingly.

## Deliberate non-findings

- There is no single khonager accent color, logo treatment, or mandatory light/
  dark mode. Product-specific identity is itself the consistent choice.
- Commit subjects show an informal iterative workflow, but spelling and `wip`
  history are not a documentation or release-writing standard.
- Existing dependency counts, folder structures, and raw token values vary with
  project age. Core records the converging direction rather than freezing the
  oldest implementation.

## Updating this audit

Revisit Core when several active projects intentionally diverge from a current
default or establish the same better pattern. Update the relevant guide and this
audit together. Do not change a shared preference based on one experiment unless
that experiment records an explicit new direction.
