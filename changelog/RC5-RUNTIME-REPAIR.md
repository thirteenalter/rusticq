# RusticQ Alpha 3 RC5 — Runtime & Widget Repair

This is a corrective RC5 build based on **rustiq-alpha-3-rc-5-settings-refactor.zip**. It is not a new release number.

## Root causes from desktop logs and screenshots

1. **Launcher count = `undefined`, search empty:** `DesktopEntries.applications` is a Quickshell `ObjectModel`, not a QtQuick `ObjectModel`. In 0.3.1 it exposes `applications.values`, an observable list, **not** `.count` or `.get()`. Search and result count now use `.values`; sorting and app-launch commands continue to use native desktop entry `execute()`.
2. **`Could not attach Keys property ... is not an Item`:** `Keys.onEscapePressed` was attached to `LauncherOverlay` (`PanelWindow`). It now belongs only to the `TextInput` inside the popup, where focus lives.
3. **Dock clipped:** previous expanded window was 76px high even though label, icon, handle, gaps and margins need more. Expanded geometry now fits its children (430×98); collapsed handle remains 82×18. The dock is optional and non-invasive.
4. **Desktop cards clipped:** the System card formerly allocated only 134px, although it contained an additional metrics row and header. Cards now measure their own content height. A `Flickable` scrolls all enabled cards if the stack exceeds the available monitor height.
5. **Task View lacking trends:** introduced `MetricWave`, a lightweight Qt Quick Canvas sparkline using measured CPU/memory samples, with a switch between process list and live graphs. No fake metrics.

## New optional desktop widgets

- **Now Playing:** player name, track title, artist and native MPRIS transport buttons. Shows a truthful idle state when no player is available.
- **Weather:** current weather condition, location, temperature and feels-like, reusing `WeatherService`.
- **Connectivity:** Wi-Fi SSID/state, Bluetooth state, and battery percentage/state from existing native services.

All new widget toggles are **off by default** under **Settings → Widgets**, persist in `user-settings.json`, and use the existing Gruvbox/Follow Aether theme tokens and Google Material Symbols font.

## Testing & limitations

Build-time checks passed: `tools/verify-static.py` for QML structural/import checks, `tools/test_settings_refactor.py`, `tools/test_rc5_runtime_repair.py`, Cloud AI offline regression, and Python compile. Qt/Quickshell executable and running Hyprland compositor were **not available**, so startup, focus, rendering, MPRIS integration and input behavior need testing on your machine.

`WARN quickshell.service.notifications: Could not register notification server at org.freedesktop.Notifications` means another notification daemon (e.g. mako, dunst, swaync) owns the D-Bus name. Only one can own it at a time. Inspect the existing owner with `busctl --user status org.freedesktop.Notifications`; deactivate the other daemon before expecting RusticQ to receive notification events. The Qt portal app-ID warning is separate.

## Suggested smoke tests

1. Launch `qs -p ./quickshell` from an extracted **full build** in a separate test directory.
2. Search for `firefox`, `terminal` or another installed `.desktop` application. Count must be numeric; Escape closes launcher without `Keys` warnings.
3. Enable Dock in Settings and hover at bottom. Confirm every icon and label stays inside the expanded dock.
4. Enable System widget, Calendar, Clock, Now Playing, Weather, Connectivity simultaneously. Verify all cards scroll rather than cut off at the screen edge. Disable individually.
5. In Task View choose Live graphs, observe CPU and memory curves updating. Return to Processes.
6. With Spotify, Firefox (media) or another MPRIS-capable player active, check title, artist, and the transport buttons in Now Playing.
7. Run `qs log -f` and report any remaining errors. The static QML checker is **not** proof of a clean runtime.

## Install without overwriting personal settings

Extract the *patch* onto your existing RC5 settings-refactor directory (it includes only changed source files and this note). Keep a backup. The *full build* contains bundled starter `user-settings.json`; install it to a separate directory first so it does not overwrite your current preferences.
