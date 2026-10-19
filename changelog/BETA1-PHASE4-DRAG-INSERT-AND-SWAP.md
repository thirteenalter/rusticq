# RusticQ Beta 1 · Phase 4 — Dual drop action hotfix

## Two drag actions in the existing bar editor

- **Insert** (preserves visible placeholder): drop in a gap or at the outer edge of another icon. An accent insertion caret appears. The dragged icon inserts at that position and the other icons shift. Uses the existing `SettingsStore.moveBarIcon()`.
- **Swap** (restores the earlier widget hotfix): drop on the central body of another icon. That card is highlighted with **↔ Swap**; both icons exchange their previous positions, including their zones when different. Uses the existing `SettingsStore.swapBarIcons()`.
- The hitbox for swap is the inner 60% of the target card width and 64% of its height. Between-card areas always insert.
- Settings storage, per-mode alignment, icon spacing, visibility, profile reset and arrow buttons are unchanged. No new dependencies, processes or autostart changes.
- Empty-zone drop inserts; dropping outside all zones leaves the saved arrangement intact.

## Compatibility and tests

- Requires **RusticQ Beta 1 Phase 4 — Drag Placeholder Hotfix** as the patch baseline. Full ZIP contains the entire current source.
- `tools/test_beta1_drag_insert_placeholder.py` runs source-extracted editor/store JavaScript through Node, checking between-card insertion, center-card swap, swaps across zones, wrapped rows, no-op drop, and per-layout isolation.
- Run `python3 tools/test_phase4_workspaces_swap.py`, `python3 tools/test_beta1_phase4_widgets_bar.py`, and `python3 tools/verify-static.py`.
- Real pointer drag gestures in Quickshell/Hyprland still require testing on your desktop.
