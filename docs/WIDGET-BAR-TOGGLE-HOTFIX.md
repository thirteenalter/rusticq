# Beta 1 — Desktop widget compatibility and Bar Visibility

## Widget runtime warning hotfix

After overwriting a local Quickshell tree with an older Swaybg Low Memory
archive, **locally added DesktopScratchpadCard/RandomImageCard files** could
remain on disk and call functions missing from the archived SettingsStore.
This release restores a safe compatibility interface:

- `workspaceNoteKey(monitor, workspace)` and `workspaceNote()` / `setWorkspaceNote()`
- `widgetAllowedOnWorkspace(kind, workspace, monitor)` and `setWidgetWorkspaces()`
- `widgetSize(kind, monitor)` and `setWidgetSize()`
- `widgetImageFolder` and `setWidgetImageFolder()` (also emits the automatic
  `widgetImageFolderChanged` QML property-notify signal)

Defaults are non-destructive: unset workspace rules show a card on all
workspaces; sizes fall back to sensible per-card defaults. Values are stored in
`user-settings.json` alongside current widget settings. Existing local cards
and user settings are not overwritten or deleted by the overlay ZIP.

**Compatibility scope:** Neither `DesktopScratchpadCard.qml` nor
`DesktopRandomImageCard.qml` is present in the provided `quickshell.zip`
source or the previous Swaybg release archive. Their original implementation
cannot be verified without those local files. This hotfix addresses the
exact missing SettingsStore API / signal errors shown in the runtime log.

## Bar visibility

- Settings → Bar → **Bar visibility**: **Show bar**, **Auto-hide**,
  **Hide bar**, and **Hide completely**.
- **Auto-hide** reveals the bar when the pointer touches its configured screen
  edge. It closes 450 ms after the pointer leaves, while an open bar popup or
  panel keeps its bar visible. Reveal state is independent on each monitor.
  This mode overlays windows without reserving workspace space.
- A hide icon on the bar itself, configurable and movable through Bar spacing
  and alignment, with independent per-layout visibility in Settings → Modules.
- **Hide bar** leaves a small **restore handle** at the configured bar edge on
  each monitor. **Hide completely** removes that handle too, with no edge hover
  trigger. Restore it with **Show bar** in Settings or a `bar-show` / `bar-toggle`
  shortcut. From a terminal, use `qs ipc -p PATH call rusticq dispatch bar-show`,
  where PATH is the running shell directory.
- Settings → Shortcuts → **Bar visibility**: register actions **bar-toggle**,
  **bar-show**, **bar-hide**, and **bar-hide-completely** (Show / hide bar completely)
  to any supported Hyprland key combination. No shortcut is
  installed automatically, avoiding collisions with Omarchy bindings.
- **Show / hide bar completely** toggles between **Show bar** and **Hide
  completely** on each press. The selected Bar visibility option updates and
  saves automatically. Existing `bar-hide-completely` bindings keep working;
  a separate Show shortcut is no longer necessary for this action.
- The setting is persisted in `user-settings.json`; hide/show applies across
  the bar's monitor instances. All existing modes and bar positions work.

For a direct test once a key is registered (replace with an assigned key):

```sh
quickshell ipc -p ~/dev/quickshell call rusticq dispatch bar-toggle
```

If the above CLI alias differs on your Quickshell version, the underlying
RusticQ IPC action is `rusticq dispatch bar-toggle`. You can also use the
Settings button or the recovery handle.

## Unrelated runtime warnings

`Could not register notification server at org.freedesktop.Notifications`
means another notification daemon currently owns the D-Bus name (for example
`mako`, `swaync`, or another Quickshell process). Only one app may own the
notification server. This patch does **not** forcibly stop that daemon.

`Could not register app ID: Connection already associated with an application
ID` is a portal registration warning, often caused by competing app IDs or
multiple shell instances. These are **separate** from the widget SettingsStore
function errors. Check running processes and the existing notification owner
before making disruptive service changes.

## Tests

Run `python3 tools/verify-static.py` and `python3 tools/check-bar-modes.py`.
`python3 -B tools/test_bar_visibility_ui.py` requires a Wayland desktop and
briefly opens test windows with isolated settings. It checks the four visibility
modes, edge hover, timing, popup hold, independent reveal state and persistence.
Physical multi-monitor hotplug still needs manual verification.
