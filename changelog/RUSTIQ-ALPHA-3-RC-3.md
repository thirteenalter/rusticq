# RusticQ Alpha 3 RC3

Target: Quickshell 0.3.1, Hyprland with Lua configuration, Gruvbox / Follow Aether.

## Changes

### Clean Compact — new On Hover option

Settings → Bar & modules → Clean Compact · Right-side labels:
- **Icons only**: Weather/date/time/Wi-Fi/Bluetooth labels hidden; battery and audio percent remain visible.
- **With details**: all applicable labels visible.
- **On hover**: reveal additional labels when pointer enters the right-side status group. Battery and audio percent remain visible.

The optional mode is saved as `cleanRightMode`, and existing RC2 `cleanRightDetails` configurations are read for migration.

### Realtime margins, per bar layout

Settings → Bar & modules → Realtime margin editor. Top/Bottom/Left/Right values (0–32 px) apply live. Changes remain separate for compact, clean-compact, separated, professional, and simple modes and persist in `marginOverrides`. **Reset mode** removes overrides for the active mode only. Switching bar position retains these per-mode overrides.

### Redesigned Settings

Settings window 1090 × 760, more spacious navigation and brand preview, larger typography, separate card groups, scrollable content and stable bottom navigation footer. Palette still comes from `Theme.qml`, not a new design system.

### Monitors — arrange, detail, apply

Settings → Displays now reads `hyprctl -j monitors` and displays real active outputs, including scale, resolution, refresh, output name and VRR. Drag each display in the preview area, or expand an individual display and choose **Left / Right / Above / Below** relative to the first *other* connected monitor. Each display expands to show available resolution+Hz options and scale choices.

1. Select **Validate** to catch invalid values and overlapping logical rectangles.
2. Select **Apply layout** to invoke Hyprland's Lua `hl.monitor` configuration via `hyprctl eval`. This changes the **current session only**. The runtime API may differ with the installed Hyprland version. Error messages appear in Settings.
3. Select **Export Lua** to write a reusable snippet to `~/.config/rustiq/monitors.lua`. It **does not modify** `~/.config/hypr/` or another compositor config. Source or incorporate the snippet manually if you want persistence.
4. **Refresh** re-reads the compositor configuration and replaces any un-applied drafts.

To restore previously saved monitor rules after an erroneous apply, use your normal Hyprland configuration reload, e.g. `hyprctl reload`. **Changing your display layout can temporarily blank or move a screen.** Avoid applying while working on an unsaved document.

The monitor helper uses Python stdlib, validates monitor names, supported mode syntax, coordinates and overlapping screens, and never invokes a shell.

### Installation

This archive is standalone, including source and bundled fonts. Make a backup of your prior RusticQ folder and your own `user-settings.json` before replacing the installation. Then:

```bash
qs -p /path/to/rustiq-alpha-3-rc-3/quickshell
```

Requirements: Quickshell 0.3.1, Hyprland, Python 3, `hyprctl`. `nwg-displays` remains optional and can be launched from the Displays tab.

### Test plan

- Switch Clean Compact among the three label options; hover the right group to verify reveal/conceal. Check volume and battery percentage are always visible.
- Change top/bottom/left/right margin in every bar mode; confirm live updates. Switch between bar modes and restart to verify persistence.
- In Displays, expand a monitor and inspect available modes, scale and status. With 2+ screens drag a monitor and validate, then apply if you accept changing the active desktop layout. Confirm no monitor overlaps.
- Confirm Appearance, AI, Quick Control, Aether and indicator popups still work.

### Testing boundaries

This release has structural QML checks and offline tests for the monitor helper, persistence and source regressions. The package **has not been run** in a real Hyprland / Quickshell 0.3.1 desktop in this environment. In particular, the Hyprland `eval` monitor syntax needs to be checked on the exact installed compositor version.
