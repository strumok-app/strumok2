---
name: tv-focus-navigation
description: 'Make screens and widgets usable on Android TV with a D-pad remote (focus, traversal, activation, back handling). Use for any UI that can appear on TV.'
---

# TV focus navigation

Rules: [platforms-and-adaptive-ui.instructions.md](../../instructions/platforms-and-adaptive-ui.instructions.md).

## Principles
- Every actionable element is reachable with arrows and activates with Select/Enter (root maps `select` → `ActivateIntent`).
- Exactly one element has initial focus on each screen (`autofocus: true` on the primary action — e.g. "Watch" on details, first card on home).
- Visible focus: scale 1.05–1.1 + outline/glow using `colorScheme.primary`; never rely on color alone.
- Horizontal rows: `FocusTraversalGroup` per row; when focus enters a row, scroll the focused card into view (`Scrollable.ensureVisible`, alignment ~0.1).
- Vertical lists of rows: keep row focus memory (returning to a row restores the last focused card).
- Back key: close menus/overlays/controls first; only then pop the route. Use `BackButtonListener`/`PopScope`.
- Avoid hover-only affordances, tiny targets, long-press-only actions, and drag-only interactions
  (provide move up/down buttons instead of drag-reorder).
- Text input only where unavoidable (search, pairing code). Submit on `onSubmitted`.
- Pagination: explicit focusable "Load more" tile at row end instead of scroll-triggered loading.

## Testing
- Run desktop with `--dart-define=FORCE_TV_MODE=true` and navigate **only** with arrow keys, Enter, Esc.
- Widget test: `await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight)` then assert `FocusManager.instance.primaryFocus` is on the expected widget (use `Key`s on focus nodes).
