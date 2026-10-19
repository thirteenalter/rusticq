# RusticQ Beta 1 — Phase 4 Widget Interaction & Swap Hotfix

## Changes

1. **Bar icon swap** (matrix #27): `SettingsStore.swapBarIcons()` exchanges slots and, when applicable, zone assignments and per-icon spacing. The drag editor resolves a destination tile from pointer release geometry. Empty-zone dropping still appends. Changes persist per bar layout mode.
2. **Kanban input** (matrix #45): `PanelWindow.focusable` is now enabled for interactive desktop widgets and the drag interception region is reduced to a top-right handle. The existing task backend remains authoritative.
3. **Freeform Notes** (matrix #45): `DesktopScratchpadCard.qml` adds a multiline `TextEdit` and debounced saving into the existing `SettingsStore` under monitor:workspace keys. Original task notes remain intact in `rusticq-notes.py`; freeform writing is intentionally independent.
4. **Workspace visibility**: `Hyprland.monitorFor(screen).activeWorkspace.id` controls visibility of Notes, Kanban and Random Image per monitor. Settings → Widgets selects workspace 1–10 for each kind, defaulting to workspace 1.
5. **Resize**: an unobtrusive bottom-right drag handle persists independent widget dimensions per monitor/workspace. Positions are also workspace-specific with fallback to legacy per-monitor positions.

## Compatibility & validation

- No changes to Omarchy startup, Hyprland bindings, dependencies, other desktop widgets, or clipboard/privacy services.
- Existing `user-settings.json` gains optional `widgetWorkspaceScopes`, `workspaceNotes`, `widgetSizes` keys. Data is filtered on load.
- Regression tests: `python3 tools/test_phase4_workspaces_swap.py`, `python3 tools/test_beta1_phase4_widgets_bar.py`, `python3 tools/test_rc4_v5_mode_profiles.py` and `python3 tools/verify-static.py`.
- No actual Hyprland/Quickshell instance in build environment; hardware mouse drag, focus and cross-workspace visual behavior require user confirmation.

## Known limitations

- Kanban cards share one task collection across workspaces; only visibility and geometry are workspace-specific.
- Interactive cards are Bottom-layer surfaces, not normal desktop application windows; resize uses a custom gesture.
- The freeform note text is not encrypted. Do not store passwords or secrets in it.

Backlog from the 50-feature matrix is intentionally unchanged and carried forward.
