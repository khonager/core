# Design system

This document defines the shared khonager visual grammar. It intentionally does
not define one universal brand. Each product should have its own identity while
remaining recognizably built with the same priorities: calm hierarchy, rounded
surfaces, controlled color, spatial interaction, and honest states.

## 1. Design from semantics

Define semantic tokens before building screens. Components consume roles such
as `surface`, `primary`, and `error`; they do not own unrelated raw colors.

Minimum color roles:

| Role | Purpose |
| --- | --- |
| `background` | Lowest application canvas |
| `surface` | Primary cards, sheets, and panels |
| `surface-elevated` | Menus, dialogs, raised inputs |
| `foreground` | Primary text and icons |
| `foreground-muted` | Supporting copy and inactive controls |
| `border` | Quiet separation; not a box around everything |
| `primary` / `on-primary` | Main product accent and readable content on it |
| `secondary` / `on-secondary` | Optional supporting identity color |
| `success`, `warning`, `error` | Meaning only, never decoration |
| `focus` | Visible keyboard/input focus |
| `scrim` | Modal and readability overlay |

Web projects should expose these as CSS custom properties, preferably HSL
channels where alpha composition is needed. Flutter projects should put them in
`ColorScheme` and a small `ThemeExtension` for roles Material does not cover.
Avoid direct `Color(...)`, hex, or palette utility values inside feature widgets
unless the color represents user content or external data.

## 2. Foundation palettes

Choose a product seed; do not reuse an accent merely to make products match.
These neutral values are starting points, not a mandatory brand palette.

| Token | Dark starting point | Light starting point |
| --- | --- | --- |
| `background` | `#111113` | `#F7F7F8` |
| `surface` | `#1C1C1E` | `#FFFFFF` |
| `surface-elevated` | `#2C2C2E` | `#EEEEF0` |
| `foreground` | `#FAFAFA` | `#171719` |
| `foreground-muted` | `#A1A1AA` | `#65656F` |
| `border` | white at 10–14% | black at 10–14% |

Rules:

- Use neutral surfaces for most of the interface. Tint a surface only when the
  product concept or state benefits from it.
- Pick one primary seed with strong contrast in both modes. A second accent is
  acceptable for paired concepts such as sleep/wake or portal endpoints.
- Derive subtle selected, hover, and focus surfaces from the seed at controlled
  opacity instead of inventing nearby colors.
- Keep semantic red, amber, green, and blue stable enough to retain meaning.
- Never communicate state by color alone.
- Support both light and dark when the product and platforms warrant it. A
  deliberate single-theme experience is acceptable when recorded locally.

## 3. Type

Default to a legible system sans-serif. Inter is the established cross-platform
choice when a bundled/web font improves consistency. A display or narrative font
needs a product reason and should not replace the reading face.

Recommended scale:

| Role | Size | Weight | Notes |
| --- | --- | --- | --- |
| Display | 40–64 | 500–600 | Hero/clock moments only |
| Page title | 28–32 | 600–700 | One per major view |
| Section title | 20–24 | 600 | Clear scan points |
| Component title | 16–18 | 600 | Cards, dialogs, list groups |
| Body | 14–16 | 400 | Default reading text; 1.4–1.6 line height |
| Label | 12–14 | 500–600 | Controls and metadata |
| Caption | 11–12 | 400–500 | Never the only place for essential detail |

Use sentence case. Reserve all caps and wide tracking for tiny category labels,
not buttons or paragraphs. Prefer two useful weights over loading an entire font
family. Text must remain usable at platform text scaling settings.

## 4. Spacing, shape, and elevation

Use a 4-pixel base grid with the working scale `4, 8, 12, 16, 24, 32, 48, 64`.
The common component rhythm is 12–16 pixels internally and 16–24 pixels between
groups. Dense tools may tighten this deliberately; touch targets do not shrink.

Shape defaults:

- small controls and inputs: 8–12 pixel radius;
- cards and panels: 12–16 pixels;
- large sheets or expressive surfaces: 16–24 pixels;
- chips, search fields, and compact primary controls: pill shape when it improves
  recognition or ergonomics;
- media: follow its containing surface unless the asset itself should remain
  square.

Prefer tonal separation and thin borders to heavy shadows. Dark interfaces use
surface steps and light borders; light interfaces may add a soft, broad shadow.
Do not stack a border, strong shadow, glow, and gradient on the same ordinary
card.

## 5. Layout and responsiveness

- Design from the smallest supported width and a useful wide composition, then
  test the space between them.
- Keep readable text lines near 45–75 characters. Do not impose a phone-width
  cap on the entire desktop application.
- On mobile, use one primary task per view with sheets or progressive disclosure
  for secondary detail.
- On tablets and desktop, promote navigation and detail into rails, docks, or
  split views when the added context is useful.
- Preserve a stable spatial anchor across breakpoints. Selection should remain
  visibly connected to its detail view.
- Respect safe areas, window chrome, on-screen keyboards, desktop resizing, and
  pointer/keyboard interaction.
- Prefer content-based breakpoints over device labels. Record named breakpoints
  in the application theme instead of scattering numeric checks.

## 6. Component language

### Buttons and actions

- One visually primary action per local decision area.
- Secondary actions are tonal or outlined; tertiary actions are text/icon based.
- Destructive actions use the error role and confirmation proportional to the
  cost of reversal.
- Icon-only buttons require a tooltip/semantic label and a practical target.
- Disable only when the reason is apparent; otherwise allow the action and show
  a useful validation message.

### Cards, lists, and navigation

- A card groups related content or affords an action; it is not the default
  wrapper for every element.
- Use spacing or dividers for simple lists. Use rounded cards for important,
  selected, media-rich, or independently actionable items.
- Selected navigation uses position, weight, fill, or indicator in addition to
  color.
- Keep bottom navigation to a small set of peer destinations. Move utilities and
  settings out of the primary product flow when possible.

### Forms and search

- Labels remain available after input; placeholders are examples, not labels.
- Prefer filled neutral inputs with a quiet boundary and a clearly accented
  focus ring.
- Validate at the relevant boundary and keep user input after recoverable errors.
- Search may use a pill shape, but filters and AI-inferred constraints must remain
  inspectable and removable.

### Dialogs, sheets, and feedback

- Use dialogs for short decisions and sheets/panels for contextual work. Do not
  hide a full workflow in a tiny modal.
- Toasts/snackbars confirm transient outcomes; persistent problems stay near the
  affected content.
- Loading indicators describe the object or step when waiting is meaningful.
- Empty states say what the area is for and offer the next useful action.

## 7. Glass, gradients, glow, and imagery

These effects are part of the recurring portfolio style, but restraint is what
makes them effective.

- Glass belongs on navigation rails, overlays, hero controls, or a small number
  of identity surfaces. Always provide a readable opaque/tinted fallback.
- Use 12–24 pixels of blur with a 10–16% light border as a starting range; verify
  contrast over the worst background image.
- Use gradients for atmosphere, product identity, state transitions, or the main
  call to action—not to compensate for weak hierarchy.
- Use glow around focused/active identity moments. Keep it broad and low-opacity
  so text and boundaries remain crisp.
- Background animation stays slow, subtle, and isolated from scroll performance.
- When deriving a background from an avatar or image, destroy recognizable
  geometry before blurring if privacy or distraction is a concern; preserve only
  the color field.
- Product art, avatars, and screenshots use intentional assets. Do not ship
  generated placeholder faces or stock starter graphics as final identity.

## 8. Motion

Motion explains relationship, state, or causality. It does not delay access.

- micro feedback: about 120–200 ms;
- ordinary component transitions: about 180–280 ms;
- page, shared-element, or crossfade transitions: about 240–400 ms;
- ambient loops: slow enough not to demand attention.

Use ease-out for elements entering, ease-in for elements leaving, and a standard
ease-in-out for continuous movement. Gestures should track the pointer/finger
directly before settling. Avoid spring overshoot on serious, destructive, or
precision interactions. Reduced motion removes parallax, large travel, repeated
pulses, and nonessential loops while preserving state clarity.

## 9. Accessibility and state gate

Before calling a screen complete, verify:

- text and meaningful controls meet contrast requirements over every background;
- keyboard focus is visible and traversal order is logical;
- screen-reader names, roles, values, and state changes are meaningful;
- touch targets are at least 44 logical pixels, preferably 48;
- 200% text scaling does not clip essential content;
- reduced motion and platform brightness settings behave intentionally;
- loading, empty, offline, error, permission-denied, partial-success, and success
  states exist where relevant;
- destructive actions state scope and recovery before confirmation;
- narrow phone and useful desktop widths have both been rendered and inspected.

## 10. Per-project design decision

Every application should record these values locally:

```text
Mood:
Primary user and environment:
Theme behavior (system/light/dark/single-theme):
Primary and secondary accent:
Typography:
Density:
Navigation model at narrow and wide widths:
Glass/gradient/motion allowance:
Accessibility or platform constraints:
Intentional Core exceptions:
```

Keep the decision short. The source theme/tokens remain the executable truth.
