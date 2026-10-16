# RusticQ Alpha 4 RC1 — Dock running apps & launcher layout fix

**Type:** corrective fix; version unchanged. **Target:** Quickshell 0.3.1 and Hyprland (including Lua-based Omarchy).

## Dock

The previous dock counted `Hyprland.toplevels.values.length` to allocate horizontal space even when the delegate could not retrieve a valid application identifier. Hidden delegates then left a blank region to the right of the shortcut icons.

The dock now uses `scripts/rustiq-running-apps.py list`, reading the actual JSON output from `hyprctl -j clients`. Mapped GUI windows are grouped by application class, with a representative window for each application. The dock recalculates its width from the **displayed** list, rather than from an unfiltered model. When **Show running apps** is off, the list and separator disappear, and no space is reserved for running applications.

Clicking a running app uses `scripts/rustiq-running-apps.py focus <address>`. The helper validates that the address contains only hexadecimal characters, dispatches the current Hyprland Lua `hl.dsp.focus({ window = "address:0x..." })`, and falls back to the classic `focuswindow` dispatcher if rejected. The helper never executes shell-interpolated text. Focus requests can still be refused by the compositor.

## App Launcher

Open **Settings → App Launcher → Launcher layout mode**:

* **Compact** (default): full launcher UI and results are immediately available.
* **Clean Compact Hover**: initial window only displays a short “App Launcher” header and search field. Results expand when the pointer enters the search field or typing begins; with an empty query, preview is limited to eight applications. The preview collapses after the pointer leaves, unless a query remains. No extra count/section/footer is shown in the compact initial state.

Window width/height, icon size, result row height, and favorite columns remain configurable independently of mode. Config is written to `user-settings.json` as `launcherLayoutMode` and older saved settings remain compatible.

## Testing

Offline:

```bash
python3 tools/test_dock_launcher_layout_fix.py
python3 tools/test_omarchy_dock_fix.py
python3 tools/test_updater_launcher_fix.py
python3 tools/verify-static.py
```

On the desktop:

```bash
hyprctl -j clients
python3 scripts/rustiq-running-apps.py list
qs -p .
```

1. Enable **Settings → Dock → Show running apps**, open two graphical applications, and wait up to 2.5 seconds for icons to populate. Click an icon to request focus.
2. Disable **Show running apps**; verify the divider and reserved running-app space disappear while shortcut icons remain.
3. Switch launcher modes in Settings. Verify Clean Compact Hover initially shows only the minimal heading and search, expands with hover or input, and returns to the compact state after leaving with an empty query.
4. Check resizing at your configured launcher width/height on each monitor.

**Limitation:** QML source verification and mocked Hyprland IPC tests are not equivalent to a live test in your Quickshell/Omarchy session. If running apps are still empty, compare `hyprctl -j clients` against the helper's JSON output, and inspect `qs log -f` for `RusticQ dock running apps` messages.
