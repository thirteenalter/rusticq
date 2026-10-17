# RusticQ dependencies (Arch packages)

The machine-readable source of truth is [`config/dependencies.json`](../config/dependencies.json). Installation checks inspect installed pacman packages; they do **not** check whether services are running. Package names below refer to official Arch repositories, not AUR.

## Core — automatic local setup

| Package | Purpose |
| --- | --- |
| `quickshell` | Quickshell runtime. Beta 1 was built against 0.3.1. |
| `hyprland` | Hyprland window compositor and monitor/workspace APIs. |
| `python` | Backend scripts and diagnostics. |
| `ttf-material-symbols-variable` | Missing local font fallback for icon glyphs. |

`quickshell` pulls its own Qt6 dependencies through pacman. You do **not** need to manually install every Qt library. Installing these packages does not launch Hyprland or enable RusticQ automatically.

## Optional — install from Settings → Integration

| Feature | Pacman packages | Notes |
| --- | --- | --- |
| Wi-Fi/Ethernet | `networkmanager` | NetworkManager service must be running. |
| Bluetooth | `bluez`, `bluez-utils` | Bluetooth service and hardware required. |
| Battery | `upower` | Not meaningful on many desktops. |
| Audio | `pipewire`, `wireplumber` | Existing desktop audio session may already provide these. |
| Media keys | `playerctl` | App must support MPRIS. |
| Brightness | `brightnessctl` | Supported sysfs/hardware permissions required. |
| Screenshots | `grim`, `slurp` | Region selection uses Slurp. |
| Screen recording | `wf-recorder`, `slurp` | Permission and Wayland capture access required. |
| Clipboard | `wl-clipboard` | Clipboard utilities. |
| Open folders | `xdg-utils` | Needed for certain menu actions. |
| Update check | `pacman-contrib` | Provides `checkupdates`. |
| Privileged system updates | `polkit` | A separate polkit agent may still be needed. |
| Night light | `hyprsunset` | Hardware/color support varies. |
| Process monitor | `btop` | Optional Shell menu action. |
| Legacy Wi-Fi helper | `jq` | The primary Quickshell network service uses Quickshell Networking. |
| Additional sensors | `lm_sensors` | Exposes supported temperature sensors. |
| Qt multimedia integration | `qt6-multimedia` | Only if needed for extended multimedia functionality. |

Optional tools are installed **one package at a time** using an interactive terminal. On Arch, pacman uses `-Syu` during installation to avoid unsupported partial upgrades; on Omarchy, its own guarded update command runs first. No `--noconfirm`, automatic AUR installs, or background package changes.

## Fonts and icons

The full ZIP excludes bundled `assets/google.ttf` and `assets/Poppins-*.ttf`. QML now falls back to the system **Material Symbols Rounded** font and **Sans Serif** respectively. The setup adds `ttf-material-symbols-variable` to support the first fallback. To use local Poppins, obtain correctly licensed files and place them under the names expected in `config/Fonts.qml`. No font downloads are performed by RusticQ's scripts.

## Diagnose

```bash
python3 scripts/rusticq-dependencies.py status
python3 scripts/rusticq-dependencies.py missing-core
pacman -Q quickshell hyprland python ttf-material-symbols-variable
```

You can also launch `bash scripts/install.sh --dry-run` without changing the system.
