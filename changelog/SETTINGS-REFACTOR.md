# RusticQ Alpha 3 RC5 — Settings Refactor Patch

This is a corrective update to RC5, not a new release candidate number.

## Why RC5 Settings overlapped

The former `SettingsWindow.qml` contained several new `Rectangle` cards inside `ColumnLayout` without intrinsic heights. Their `ColumnLayout` children were anchored to those rectangles but did not provide implicit heights back to their parents. In the scroll viewport, many rectangles collapsed to zero or near-zero height, causing several independent settings sections to render at the same Y position.

## Source changes

- `modules/settings/SettingsWindow.qml` is now a small navigation shell with a single page loader, one scroll viewport, and a dedicated settings search list.
- `modules/settings/SettingsSection.qml` sizes each card explicitly with `implicitHeight: content.implicitHeight + 30`, instead of deriving its height from `anchors.fill`.
- `modules/settings/pages/*` isolates eight pages: Appearance, Bar, Modules, Widgets, Dock, Displays, AI Providers, and About.
- Bar position, mode, Clean Compact labels and per-mode margin slider remain in **Bar**. Individual icons, Quick Modes and File/Edit/View/Share appear in **Modules**. Desktop widgets and Dock settings no longer share the Bar page.
- Existing `SettingsStore` keys, `user-settings.json`, theme tokens, and cloud API/keyring flows remain unchanged.
- `modules/main/LauncherOverlay.qml` centers an app search window on the monitor where its button was clicked. The search card is 650px wide on sufficiently large monitors.
- `modules/main/MiniLauncher.qml` now filters actual `DesktopEntries.applications` objects (rather than relying on zero-height `ListView` rows), and sends the selected app to `DesktopEntry.execute()`.
- The launcher entry in the dock opens the same native launcher; no additional rofi/wofi/fuzzel requirement.

## Install

### Recommended: patch only

Back up your current RusticQ folder and `user-settings.json`, then merge the contents of `quickshell/` from the patch ZIP over your current `quickshell/` directory. The patch has no `user-settings.json`, no font files, and no changes to the original theme.

### Full source

The complete ZIP can be extracted separately for testing. If you use it over an existing configuration, preserve your existing `user-settings.json` first.

Run from the directory containing `shell.qml`:

```sh
qs -p .
```

## Testing

1. Open Settings, switch through all eight sidebar pages.
2. Open **Bar**, scroll through positioning, five modes, Clean Compact policy and the realtime margin editor; no text or cards should overlap.
3. Open **Modules**, toggle Wi-Fi or another individual icon; its bar visibility should update and the preference should persist.
4. Open **Widgets** and **Dock**, verifying their controls remain independent of Bar.
5. Select the launcher icon on any bar edge or the dock. A wider search card should appear at the center of the associated monitor. Type the name of an installed application and select the matching result.
6. Close the launcher with Escape or click outside.
7. Check **Displays** and **AI** retain their existing functions.

### Validation limitations

The source was statically audited, glyphs were checked against `assets/google.ttf`, and `tools/test_settings_refactor.py` passed. The development environment does not have the `qs` executable or a live Hyprland session. Runtime visuals and application launching must be verified on your desktop; do not treat static tests as a guarantee of successful startup.
