# Hotfix 9 — Aether live palette & indicator mini widgets

Target: Arch Linux / Hyprland / Quickshell **0.3.1**. This revision is based on the user-supplied `quickshell.zip`, not an older hotfix.

## Color source

**Full Settings → Appearance → Color source**:

- **Independent Gruvbox** (default): preserves the original `#282828`, `#3c3836`, `#ebdbb2` palette and independently selected Gruvbox accent.
- **Follow Aether**: reads *applied* `~/.config/aether/theme/colors.toml` without running Aether or changing the wallpaper. It maps `background`, `foreground`, `accent` (or `color4`), and ANSI `color1`, `color2`, `color3` into existing `Theme` tokens, and derives muted/surface/border colors from the base colors. All modules using `Theme` update when the singleton changes.

Aether must have generated the file by clicking **Apply Theme** or using its documented CLI. `FileView` watches changes, and an 8-second refresh protects against atomic file replacement. An absent/malformed palette leaves the Gruvbox fallback in use; temporary invalid writes do not override a previously good palette. Independent mode does not alter or write Aether files. Source setting persists to `user-settings.json`, never to the Aether file.

Check the source with:

```sh
ls -lh ~/.config/aether/theme/colors.toml
# Then use Aether's Apply Theme and watch the palette update.
```

Reference: https://github.com/omacom/aether/blob/main/docs/standalone.md

## Clickable per-indicator mini controls

The system-indicator pill now contains **Bluetooth, Wi-Fi, Battery, Audio**. Each individual icon/label is an actionable hit target and opens an anchored, focus-dismissing `PopupWindow` below its position on the bar:

- Wi-Fi → `BarWifi.qml` reused, with network list/password workflow
- Bluetooth → `BarBluetooth.qml` reused, with device controls
- Battery → `BarBattery.qml` reused, with profile switcher
- Audio → `MiniAudio.qml`, exposing PipeWire sink volume/mute via native API

One popup at a time, with one shared popup wrapper per bar. Quick Control remains accessible from its original toggle; clicking an indicator closes the full sidebar before opening a mini control. Click outside to dismiss the mini popup (Quickshell `grabFocus`). The popup is anchored to its own monitor's bar window.

Reference: https://quickshell.org/docs/v0.3.1/types/Quickshell/PopupWindow/

## Date and fonts

The bar date shows a localized weekday in addition to date: `ddd, dd MMM` for compact modes, `dddd, dd MMM` otherwise. Dates are visible in all bar modes. Poppins and Google Material Symbols are retained.

## Runtime checklist

1. `qs --version` → expected 0.3.1; run `qs -p ./quickshell` from the extracted directory.
2. Click each of the 4 indicator targets on multiple monitors. Check that popups appear next to their bar icons, aren't clipped, close by clicking outside, and never display multiple widgets together.
3. Open Settings → Appearance; switch Gruvbox/Aether with the Aether file absent, then with an Aether theme applied. Verify the palette updates after changing the applied wallpaper.
4. Check the day/date in Compact, Clean Compact, Separated, Professional, and Simple modes.
5. Verify Wi-Fi connect/disconnect, Bluetooth discovery, battery power-profile change, and audio mute/volume. Device/service permissions are required on the actual machine.
6. Capture `qs log -f` for any runtime errors. Static checks can't validate the user's Hyprland, audio devices, or Bluetooth hardware.

No `.git/`, credentials, or font source redistribution outside the user-provided project were added. No OpenAI/Claude/Gemini API-key settings were changed.
