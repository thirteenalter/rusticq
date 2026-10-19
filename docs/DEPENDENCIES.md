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
| Wi-Fi sharing QR | `qrencode` | Optional, generates QR PNG in a private runtime directory. Python `qrcode` is an alternative. |
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

Optional tools are installed or removed **one package at a time in Settings** after explicit confirmation and GUI Polkit authorization. The selected pacman command uses `--noconfirm` only because the GUI already gathered confirmation and cannot answer CLI prompts. On Arch, package installation can run a full `-Syu` upgrade (no partial upgrades); on Omarchy, only guarded pacman package operations are attempted and a hook may reject them. System upgrades on Omarchy remain in its supported updater workflow. No AUR or Flatpak transactions are attempted by this manager. Install the system's `polkit` and a compatible **graphical Polkit agent** for authentication.

## Fonts and icons

The full ZIP excludes bundled `assets/google.ttf` and `assets/Poppins-*.ttf`. QML now falls back to the system **Material Symbols Rounded** font and **Sans Serif** respectively. The setup adds `ttf-material-symbols-variable` to support the first fallback. To use local Poppins, obtain correctly licensed files and place them under the names expected in `config/Fonts.qml`. No font downloads are performed by RusticQ's scripts.

## Diagnose

```bash
python3 scripts/rusticq-dependencies.py status
python3 scripts/rusticq-dependencies.py missing-core
pacman -Q quickshell hyprland python ttf-material-symbols-variable
```

You can also launch `bash scripts/install.sh --dry-run` without changing the system.

## Beta 1 Phase 2 launcher tools (optional)

| Launcher tool | Packages / service | Behavior and privacy |
| --- | --- | --- |
| Emoji `:emoji` | `wl-clipboard` | Copies only the chosen symbol; search needs no dependency. |
| Screen color `:color` | `hyprpicker`, `wl-clipboard` | Picker must be chosen explicitly. Reports HEX/RGB/HSL locally. |
| OCR `:ocr` | `grim`, `slurp`, `tesseract`, `wl-clipboard` | Explicit region selection; text copied locally; no network. |
| Wallpaper `:wallpaper` | Running `swww`, `awww`, or `hyprpaper` | Uses existing RusticQ wallpaper setter. Images are not uploaded. |
| Settings `:settings` | No new package | Existing Settings and Store state only. |
| Scientific + unit calculator `=...` | Python 3 | Safe AST and fixed conversion table; optional `wl-clipboard` when copying. |

Install optional packages from **Settings → Integration** if missing. The installer only auto-installs its existing core dependency set. `notify-send` from `libnotify` is optional for success/error feedback when color/OCR runs after closing the launcher.

## Beta 1 — GUI package sources and keyboard power menu

**Settings → Installed Apps** searches all available providers by default:
`pacman -Ss` for official repository packages, `yay -Ssa` for **AUR only**,
and `flatpak search` for configured Flatpak remotes. Separate provider chips filter results, while each result retains its own provider for GUI install/removal.

| Provider | Optional dependency | Authorization and important notes |
|---|---|---|
| Pacman | `pacman`, `polkit`, running Polkit agent | Graphical `pkexec` for system changes; Omarchy pacman hooks remain enforced |
| Yay (AUR) | `yay`, `base-devel`, running Polkit agent | Yay is **never executed as root**; privileged pacman phases can use `pkexec`. AUR PKGBUILDs are third-party code. Review packages before installing. |
| Flatpak | `flatpak` + configured remote (e.g. Flathub) | User Flatpaks run without sudo; system Flatpaks use Flatpak's own authorization; `--noninteractive` avoids terminal prompts |

**Power menu:** Open **Shell → Power menu** or use `quickshell ipc ... call rusticq power` (or assign the new action in **Settings → Shortcuts**). Arrow keys or numbers select, Enter twice confirms, Esc closes. Native Lock requires Quickshell 0.3.1+ and the existing system PAM login policy. The ASCII Screensaver requires Omarchy; Hyprlock is only an optional fallback. Other actions need Hyprland `hyprctl` and systemd `loginctl`. A polkit agent may be required for system actions. No idle daemon is started.

**Limitations:** AUR package hooks and build scripts execute locally; automatic noninteractive builds cannot substitute for reviewing PKGBUILDs. Yay may reject builds needing additional interaction or PGP confirmation. Flatpak search requires a configured remote. GUI operation errors are returned to Settings; no hidden terminal is started.

## RusticQ Lock Screen

The native RusticQ lockscreen uses Quickshell `WlSessionLock` and `PamContext` against `/etc/pam.d/login`. It does not install or modify PAM rules or Omarchy lock configuration. Hyprlock remains optional for explicit fallback. Open Settings → Appearance → RusticQ Lock Screen or see `docs/LOCKSCREEN.md`. Omarchy's ASCII screensaver is unchanged.
