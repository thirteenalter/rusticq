# Hotfix 5 — Gruvbox UI, System, Monitors, Full Settings, Arch AI

**Tested against source/layout from Hotfix 4. Target: Quickshell 0.3.1, Arch Linux, Hyprland.**
The code was statically checked; there was no Quickshell+Hyprland runtime available in the build environment. Test interactively on your desktop.

## Changes
- Every card uses a shared `components/SectionHeader.qml` with the same icon / title / spacer / chevron pattern (15px Poppins Semibold title, 20px Material Symbol).
- System rewritten without animated/hidden implicit height dependency; CPU/memory/disk/temperature visible on first open.
- Storage includes actual `df` **available** bytes (GiB free), not `total - used` (these can differ on filesystems with reserved capacity).
- Advance > Screen includes backlight slider and monitor overview read via `hyprctl -j monitors`, with one-click `nwg-displays` launch for resolution, refresh rate, scale, arrangement and persistent Hyprland Lua config.
- Advance > SEE FULL SETTINGS opens a separate Quickshell `FloatingWindow` with Appearance, Bar, Displays, AI and About sections.
- Settings persist to `user-settings.json`; supports 4 accent colors from Gruvbox palette, toggles for weather/workspaces/indicators, and local Ollama model name.
- Clicking left Arch logo opens a LEFT AI sidebar, matching Quick Control dimensions and vertical margins. Clicking outside dismisses it. The AI uses local Ollama only (no embedded API keys); chat data is kept in memory for the current sidebar session.
- UI colors, fonts, and original Gruvbox background/surface/foreground preserved.

## Install
Unzip the complete `quickshell` directory into a separate test directory and run:

```bash
qs -p ./quickshell
```

**Do not copy only a few files**: new QML components and `config/qmldir` additions are required.

Optional dependencies on Arch:

```bash
sudo pacman -S nwg-displays curl brightnessctl
```

For local AI, install and start Ollama by following its official instructions. Then:

```bash
ollama pull llama3.2
ollama serve
```

Set your actual installed model in Full Settings > AI (default `llama3.2`). If Ollama is installed as a systemd service, use that service instead of starting a second server manually.

Hyprland >=0.55 (Lua): `nwg-displays` requires its monitor rules to be loaded correctly; refer to its README (`require("monitors")` in the Hyprland Lua config). A read-only overview works without nwg-displays installed; pressing the launcher button requires the program.

## Suggested smoke test
1. Start shell (`qs -p ./quickshell`) and check errors in `qs log -f`.
2. Open Quick Control, toggle Wi-Fi/Bluetooth/Battery/System; verify header size and contents.
3. Check Disk's GiB free against `df -BG /` and `df -B1 /`.
4. Open Advance > Screen > Refresh; verify output name/resolution and `nwg-displays` launcher.
5. Click SEE FULL SETTINGS; select another accent, close, restart, verify saved accent; turn Weather off/on.
6. Click Arch left on bar; verify left AI panel has the same height and top/bottom margins as right Quick Control.
7. Start Ollama, send one prompt. When Ollama is unavailable, confirm the panel displays an informative error (not a fake reply).

## Limitations / scope
- Monitor changes are made in `nwg-displays`, NOT blindly applied through `hyprctl keyword monitor`: this prevents accidental invalid layouts on Hyprland's Lua config.
- The AI panel requires the optional local Ollama backend and a downloaded model; no cloud provider/auth UI is included.
- No claim of live startup testing: user-side Quickshell 0.3.1 log feedback is required to verify runtime behavior.
