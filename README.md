> **Current revision: Hotfix 9 (Quickshell 0.3.1)** — Start with [HOTFIX9-COMPACT-SETTINGS.md](HOTFIX9-COMPACT-SETTINGS.md) for aligned Settings rows, Compact information pills, and Clean Compact. Older HOTFIX notes are historical. Cloud AI replaces the optional Ollama backend.

> **Hotfix 3 (Quickshell 0.3.1):** fixes `WifiManager is not a type` by registering the regular `WifiManager` component in `services/qmldir`. See `HOTFIX3-WIFIMANAGER.md`.

# Quickshell — Gruvbox Bar (Arch Linux, 0.3.1-compatible)

Baseline: **Quickshell v0.3.1**, Qt 6, Wayland/Hyprland.

## Version notes: Arch Linux Quickshell 0.3.1

- This ZIP targets the Quickshell version confirmed by the user: `Quickshell 0.3.1 (distributed by Arch Linux)`.
- Quickshell 0.3.2 is mostly a maintenance release; this configuration uses APIs documented in 0.3.1.
- Upstream 0.3.1 can report some *open* Wi-Fi networks as `WifiSecurityType.Unknown`. The Wi-Fi card now tries the native `connect()` method for these rather than incorrectly blocking the network as "unsupported security". Actual encrypted/enterprise networks may still require NetworkManager's own setup tools.
- The earlier `targetScreen` error was a QML component/property mismatch, not proof of an API removal from 0.3.1.

## Installation

```bash
mkdir -p ~/.config/quickshell
cp -a ./quickshell/. ~/.config/quickshell/
qs -p ~/.config/quickshell
```

If the folder is located at `~/.config/quickshell`, the default `qs` command should work too. Back up an existing Quickshell setup before copying.

Requirements: Quickshell with Hyprland and Networking support; Hyprland compositor; NetworkManager for the native Wi-Fi card; BlueZ for Bluetooth; UPower for battery detection; `curl` and internet access for the optional wttr.in weather; `ip` for the optional USB tether detection. Bundled **Poppins** and **Material Symbols Rounded** fonts are loaded from `assets/`.

## Hotfix 1 — startup error in modules/main/Bar.qml

- Removed `PowerButton { targetScreen: barWindow.screen }` (previously line 36).
- The sidebar toggle is now defined directly in `modules/main/Bar.qml`, and uses the current bar window screen and the existing `Store` singleton. This avoids a hard runtime dependency on an extra custom `targetScreen` property in the PowerButton component, while keeping Gruvbox colors/sizing.
- `components/PowerButton.qml` remains in the archive for reference/backward compatibility but is no longer instantiated by the top bar.
- If you are merging manually, **replace the entire `modules/main/Bar.qml` file**. If the error is still reported on line 36, Quickshell is loading an older copy: check `qs -p /home/ryznxx/dev/quickshell` and compare the file on disk.
- Quickshell runtime remains untested here (requires your Hyprland session).

## What works / changes made

- One responsive top bar per screen (Quickshell `Variants`).
- Gruvbox palette is centralized in `config/Theme.qml`; Poppins font loaders in `config/Fonts.qml`.
- Clickable Hyprland workspace buttons (1–6); focused workspace highlighting.
- Current system clock and weather with graceful no-data placeholder. The weather endpoint requires network connectivity.
- Native NetworkManager Wi-Fi indication, native BlueZ Bluetooth status, and UPower battery indication (hidden if no system battery).
- Rightmost toggle opens the **Quick Control** sidebar on that screen. Outside-click closes it through HyprlandFocusGrab; the close button also works.
- Wi-Fi panel: list, scan, radio toggle, connect/disconnect, forget, password prompt for WPA-PSK/WPA2-PSK/SAE, and connection failure messages.
- System monitoring panel retained with the original card style, now using palette tokens for warning/danger/healthy colors.
- Added missing `services/qmldir` registrations; removed references to undefined style tokens / font aliases.
- No recurring Wi-Fi/Bluetooth/battery shell commands; these use Quickshell services. USB tether detection is still a low-frequency fallback; system metrics and optional weather use external commands.

## Scope & known limitations

- **Hyprland-specific** workspace switching and focus grab. This is not a generic X11/Sway configuration.
- Networks requiring EAP/enterprise, OWE, WEP, or captive-portal login are intentionally not given a misleading simple-password flow. Configure them in NetworkManager settings.
- `modules/power/PowerMenu.qml` is an inactive prototype (its actions remain placeholders). `modules/process/ProcessManager.qml` is also an inactive placeholder; neither is instantiated by `shell.qml`.
- Thermal measurements depend on `/sys/class/thermal/thermal_zone*` and may be inaccurate for your CPU; update the sensor if needed.
- The original backup `modules/main/Bar.qml.bak` is included as reference only; it isn't loaded.
- **No Linux/Hyprland runtime is available in this build environment.** Static verification was performed; integration checks (actual desktop session, Wi-Fi credentials, and hotplug screens) must be run locally.

## Local smoke tests

```bash
qs --version
qs -p ~/.config/quickshell
# in another terminal, inspect output / live errors:
qs log
```

Suggested checks: workspace click and highlight; open/close sidebar; Wi-Fi scan/toggle/connect/password/forget; Bluetooth connected-device status; battery present/charging status; clock; no-data weather fallback; system metrics; 2-monitor hotplug. For defects, capture `qs log` and your installed Quickshell/Hyprland versions.

Documentation reference: https://quickshell.org/docs/v0.3.1/
