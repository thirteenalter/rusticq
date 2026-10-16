# RusticQ RC5 · Runtime & visual patch (no version bump)

Target: Quickshell 0.3.1 (Arch Linux) with Hyprland.

## Fixes

- **MetricWave:** removed unsupported Canvas reset call, paints incoming CPU/memory data with an adaptive vertical range for low CPU usage. Samples are collected continuously in SysMonService, not only while a widget happens to be open. Data are from `/proc/stat` and `/proc/meminfo`; no mock data.
- **Independent desktop widget placement:** Clock, Calendar, System Monitor, Now Playing, Weather, Connectivity now have their own Wayland Bottom-layer panel. Drag the card's top 34px header to reposition. Positions are clamped to the monitor area, normalized (0–1), and saved by monitor and widget type in `user-settings.json`. A reset action is available in Settings → Widgets. Cards remain behind standard app windows.
- **App Launcher:** real desktop-entry icons from Quickshell.iconPath (including absolute-file icons), launcher usage and pinned favorites with a top section, prioritized app search. Use the star control to pin/unpin apps. Usage stored separately in `app-usage.json` and written only on launch or pin action. Missing icons fall back to initials. Favorites will become populated as you open/pin apps.
- **Audio / Launcher:** eliminated inner card borders; one outer popup frame is retained. Audio Advanced increases popup height rather than clipping its controls.

## Install safely

Archive `quickshell/` is a full replacement but it does **not** include `user-settings.json` or `app-usage.json`. Back up your current config and merge the files, preserving existing preferences.

```bash
qs -p /path/to/quickshell
qs log -f
```

## Smoke tests on Hyprland

1. Open Task View → Live graphs. Verify a line begins to draw and changes with actual load. The first usable sample may take ~2 seconds.
2. Enable desktop Clock, Calendar and System in Settings → Widgets. Drag each using its header. Restart Quickshell and verify positions persist on the same monitor. Try Reset positions.
3. Open App Launcher, confirm app icons load. Pin two apps with the star and launch another twice; reopen to see Pinned & frequently used. Check that normal search still works.
4. Open Audio, then Advanced; verify it expands and nothing is clipped. Inspect borders on Audio and App Launcher.
5. Test both Gruvbox and Follow Aether. On multi-monitor systems, check repositioning for each monitor.

## Known limitations

- Desktop widgets on the Bottom layer can be covered by ordinary windows (intentional).
- This environment has no `qs` executable, Wayland session, or Hyprland. QML structure and source regressions can be tested here; real layout/drag performance must be tested on desktop.
- Some applications do not supply an icon in their desktop entry; those use a text fallback.
- Existing unrelated notification-daemon ownership warnings are not addressed by this patch.
