# Design and UX principles

- Start from the platform's conventions and depart only for a user benefit.
- Make hierarchy legible through spacing, type, position, and contrast before
  adding decoration.
- Design responsive structure, not a single screenshot width.
- Support keyboard navigation, screen readers, text scaling, sufficient
  contrast, reduced motion, and touch targets from the first implementation.
- Define loading, empty, offline, partial-success, error, permission-denied,
  and destructive-confirmation states for every important flow.
- Preserve user input across recoverable errors and make retry behavior clear.
- Keep motion purposeful, interruptible, and subordinate to comprehension.
- Use real content extremes: long translations, missing images, slow networks,
  large text, many items, and no items.
- Review built screens and complete flows, not only source designs.

Material visual changes should include screenshots and a short decision note in
the application repository. Accessibility regressions are functional defects.

