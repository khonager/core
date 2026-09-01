# Design and UX principles

- Start from the platform's conventions and depart only for a user benefit.
- Make hierarchy legible through spacing, type, position, and contrast before
  adding decoration.
- Make the primary action obvious without making every action visually loud.
- Prefer direct manipulation, progressive disclosure, and short paths over
  nested settings or explanatory screens.
- Design responsive structure, not a single screenshot width.
- Support keyboard navigation, screen readers, text scaling, sufficient
  contrast, reduced motion, and touch targets from the first implementation.
- Define loading, empty, offline, partial-success, error, permission-denied,
  and destructive-confirmation states for every important flow.
- Preserve user input across recoverable errors and make retry behavior clear.
- Keep motion purposeful, interruptible, and subordinate to comprehension.
- Keep navigation and spatial transitions continuous. If a gesture begins on a
  visible object, that object should remain the user's anchor while it moves.
- Use real content extremes: long translations, missing images, slow networks,
  large text, many items, and no items.
- Review built screens and complete flows, not only source designs.
- Use concise, plain-language copy. Buttons start with verbs; errors say what
  happened and what the user can do next; privacy and AI copy names the actual
  data flow instead of relying on reassuring adjectives.

The visual defaults, token model, and component guidance live in
[`design-system.md`](design-system.md). Product-specific art direction remains
local to each application.

Material visual changes should include screenshots and a short decision note in
the application repository. Accessibility regressions are functional defects.
