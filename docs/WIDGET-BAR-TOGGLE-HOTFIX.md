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

## Show/hide bar

- Settings → Bar → **Bar visibility**: Show bar / Hide bar buttons.
- A hide icon on the bar itself, configurable and movable through Bar spacing
  and alignment, with independent per-layout visibility in Settings → Modules.
- When hidden, a small **restore handle** remains at the configured bar edge
  on each monitor. Clicking it shows the entire bar again.
- Settings → Shortcuts: register actions **bar-toggle**, **bar-show** and
  **bar-hide** to any supported Hyprland key combination. No shortcut is
  installed automatically, avoiding collisions with Omarchy bindings.
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

Run `python3 tools/test_widget_compat_bar_visibility.py` and
`python3 tools/verify-static.py`. Actual `qs -p .` on Hyprland and the
local-only widget QML files must still be tested on the target machine.
