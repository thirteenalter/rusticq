# RusticQ Alpha 3 RC2 — Release candidate

**Target:** Quickshell 0.3.1 / Hyprland (Arch Linux)
**Base:** Alpha 3 RC1 — not a fresh rewrite. Original Gruvbox and Follow Aether colors retained.

## Fixes

- Restored opaque `Theme.background` inside `IndicatorPopup` for Wi-Fi, Bluetooth and Battery. The **top-level PopupWindow remains transparent** for genuinely rounded corners; each card still owns its own border, and no extra border is drawn around single widgets.
- Kept the calendar, weather, time, menus and audio popups on the same opaque background.
- Expanded **Full Settings** to a more spacious, consistent two-pane layout with categorized, reusable rows and accessible switches.

## Clean Compact

Settings → Bar & modules → select **Clean Compact**, then **Clean Compact · Right-side labels**:

- **Icons only:** hide weather, time, date, Wi-Fi and Bluetooth labels; icons remain clickable.
- **With details:** show weather/time/date labels and Wi-Fi/Bluetooth details.
- **Battery percentage and volume percentage remain visible in both modes.** Their status data is never synthesized.
- The switch changes only the horizontal bar's **right-hand group**; left-side workspaces and menu stay unchanged. Vertical bars keep their readable icon-only rail.

## Individual bar modules

**Bar & modules → Modules & individual icons** can independently show/hide: Arch AI launcher, workspaces, weather, time, date, Bluetooth, Wi-Fi, battery, volume, Quick Control, and Quick modes. The System indicators master switch remains available for convenience. Defaults preserve the RC1 appearance.

Warning: if you hide Arch, Quick Control and the optional menu bar simultaneously, you might have no onscreen entry point to Settings. To recover, restore their keys to `true` in `user-settings.json` or move the JSON aside and relaunch. Back up the existing JSON first.

## Optional desktop menu categories

**Bar & modules → Menu bar** provides separate switches for **File, Edit, View, Share, Shell, Tools**. Menu bar itself remains **off** by default. When enabled, **Edit, View, Share** are enabled by default; **File, Shell, Tools** are opt-in.

- File: Home, Downloads, RusticQ configuration folder
- Edit: Appearance, Bar & modules, AI settings
- View: Compact, Clean Compact, Separated, Professional, Simple
- Share: local captures using grim/slurp
- Shell: launch terminal and optionally btop/htop
- Tools: open Settings or take a region screenshot

File/Shell actions use `scripts/rustiq-menu-action.sh` with fixed allow-listed verbs. Nothing from the menu is interpreted as an arbitrary command. File-related shortcuts require `xdg-open`; terminal actions need a supported terminal; screenshot controls require `grim` and `slurp`.

## Compatibility and limitations

- Existing keys in `user-settings.json` are migrated by optional reads and safe defaults; cloud AI API keys remain in the Linux keyring, not JSON.
- Alpha 3 four-side bar layout, five layout modes, color sources, Quick Control accordion, mini widgets and cloud AI were not removed.
- No full Wayland compositor or Quickshell executable is present in the build environment. Structural checks and source regressions have passed, **not a runtime screenshot test**. Treat this as a release candidate until tested on Hyprland.

## Applying this source-only release

This ZIP excludes bundled font binaries and `user-settings.json`, so it does not overwrite your existing saved preferences. To keep the original design fonts and Material Symbols, **extract RC2 over a copy of an existing Alpha 3 RC1 or other RusticQ installation** and do not delete the old `quickshell/assets/` directory. The QML still references the original `Poppins-*.ttf` and `google.ttf` from that installation. Verify they remain available before running `qs`. Do not deploy the source-only ZIP into an empty directory without supplying your original font assets locally.

## Quick smoke test

```bash
qs -p ./quickshell
qs log -f
```

1. Open mini Wi-Fi, Bluetooth, Battery, calendar/time/weather and verify no desktop shows through card content; cards have rounded corners without duplicate frames.
2. Choose Clean Compact → Icons only / With details; ensure **battery and volume numbers persist** and only right side changes.
3. Disable and enable each status indicator; inspect all four bar positions and check no phantom spacing.
4. Enable menu bar and optional File/Shell/Tools; verify enabled categories appear, Edit/View/Share still work; try Terminal only when one is installed.
5. Check Full Settings at small and large window sizes; scroll independently of left navigation.
6. Confirm old `user-settings.json` choices remain compatible and new choices persist after restarting.
