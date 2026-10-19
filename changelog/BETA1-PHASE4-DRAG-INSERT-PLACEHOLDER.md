# RusticQ Beta 1 · Phase 4 — Visible drag insertion placeholder

## Fix

- **Settings → Bar → Drag to reorder** now draws a highly visible accent placeholder **between icons**, including when icons wrap onto another row and when dragged between Left / Center / Right.
- The placeholder follows the dragged item and marks the **actual insertion slot**. Releasing inserts that icon at the marked boundary; the remaining icons shift. Previously dragging onto a tile swapped the two icon slots, with no between-card preview.
- Dropping in an empty zone inserts the icon there; dropping outside all zones leaves the existing order unchanged.
- Preview geometry does not participate in the `Flow` layout, preventing tiles from jumping during a drag.
- Layout-specific icon order and zone placement remain persisted by the existing `SettingsStore.moveBarIcon()` implementation; other layouts are unaffected. The older `swapBarIcons()` API is retained for compatibility but is not called by the drag editor.
- Arrow buttons (‹ and ›), spacing settings, per-layout visibility, and Reset mode remain available.

## Test coverage

- Unit tests execute the **actual source-extracted QML JavaScript** slot selection, insertion and cross-zone persistence in Node with mocked QQuickItem geometry.
- Regression checks cover wrapped rows, empty zone, outside drop, saving only the active layout, existing widget functionality, and bar render order.
- No Quickshell/Wayland runtime is available here; **check the moving placeholder and mouse release** in your Hyprland session after applying this patch.

## Installation

Extract the **patch ZIP** from the parent folder of your `quickshell` directory (for example: `unzip -o rusticq-beta1-phase4-drag-placeholder-patch.zip -d ~/dev`). Requires the previous **Beta 1 Phase 4 Widget Interaction Hotfix** as base. No installer and no personal settings changes.
