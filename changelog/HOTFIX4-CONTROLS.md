# Hotfix 4 — Quickshell 0.3.1 / Arch / Hyprland Lua

This archive is based on hotfix3 and preserves the original Gruvbox Dark
Theme.qml, Poppins fonts, Material Symbols (`assets/google.ttf`), and bar layout.

## Fixes

1. **Battery previously displayed ~1% at high charge**: Quickshell's UPower
   percentage is a 0..1 fraction (its DBus adapter divides by 100). Now
   `Math.round(battery.percentage * 100)` is used, preferring an actual laptop
   battery if multiple devices are exposed. Charging/full/discharging uses
   `UPowerDeviceState`, and the bar shows percentage alongside Google icons.
2. **Hyprland workspace dispatch**: modern Lua mode uses
   `hl.dsp.focus({ workspace = "N" })` via `Hyprland.dispatch`, with a legacy
   fallback based on `Hyprland.usingLua`. Existing workspace highlighting stays.
3. **Quick Control**: Wi-Fi can collapse. Bluetooth and Battery now have
   expandable cards, just like the existing System card. The outer Quick
   Control area scrolls to make all cards accessible on smaller monitors.
4. **Bluetooth**: native BlueZ/Quickshell adapter toggle, discovery toggle,
   device list, pair/connect/disconnect. Some pairing workflows require an
   interactive Bluetooth agent, such as blueman-applet.
5. **Power profiles**: native Quickshell UPower PowerProfiles selectors:
   Power Saver, Balanced, Performance (disabled when unsupported).
6. **Advance**: the bottom footer is now a functional ADVANCE button. It
   switches to a separate *page within the same sidebar*, with a Back button.
   Supports PipeWire output and microphone volume/mute, selecting output
   devices, laptop-backlight brightness, and MPRIS play/previous/next.
7. **Google icons**: kept the bundled Material Symbols; newly used codepoints
   are checked against the font cmap. Theme colors are unmodified.

## Required / optional system services

- `quickshell` 0.3.1, Hyprland, Qt 6 (existing base)
- `upower` running for battery status
- `power-profiles-daemon` for power saver / balanced / performance; your
  hardware may not expose a performance mode. If `tuned-ppd` is being used,
  use the equivalent power profile provider (do not run conflicting daemons).
- `bluez` + `bluetoothd`, plus a pairing agent for authenticated pair requests
- `pipewire` + `wireplumber` for native audio
- `brightnessctl` for backlight slider (`sudo pacman -S brightnessctl`);
  membership in the relevant udev group/ACL can be needed to write brightness.
  This controls laptop backlight only, not DDC external-monitor brightness.
- MPRIS player (Firefox, VLC, Spotify, etc.) for media card.

## Run (from the directory containing the `quickshell` folder)

    qs -p ./quickshell

## Smoke test on real Hyprland session

1. Check whether the battery percentage agrees with `upower -i` and whether
   plugging/unplugging toggles the charging icon. The raw DBus percentage is
   0..100, whereas Quickshell property `percentage` is 0..1.
2. Click workspace buttons 1 through 6 (Hyprland Lua and legacy behavior).
3. Expand/collapse Wi-Fi, Bluetooth, Battery, and System. Scroll to System.
4. Toggle Bluetooth, start/stop discovery, pair/connect as applicable.
5. Select the three profiles. Performance is intentionally disabled when
   PowerProfiles.hasPerformanceProfile is false.
6. Click ADVANCE; test output and mic sliders/mute, output device switching,
   brightness, media controls. Click BACK or arrow to restore Quick Control.
7. Close/reopen sidebar; confirm it resets to Quick Control.

## If something fails

    qs log -f
    qs --version
    hyprctl version
    upower -e
    powerprofilesctl get
    brightnessctl -c backlight -m
    bluetoothctl show
    wpctl status

Note: QML was statically inspected for balanced delimiters, local imports,
`qmldir` entries and icon glyphs. A full Hyprland + Quickshell runtime is not
available in the build environment, so local integration testing is still
required. This patch does not auto-run `sudo` or install packages.

API references:
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.UPower/UPowerDevice/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.UPower/PowerProfiles/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/BluetoothAdapter/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/Pipewire/
- https://wiki.hypr.land/configuring/core/advanced-configuration/using-hyprctl/
