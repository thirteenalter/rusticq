# RusticQ Beta 1 — Feature inventory

This is a **functional map of the current source**, not a promise that every module works on every machine. Entries below link to the relevant implementation directories.

## Shell and bar

| Feature group | Features | Source |
| --- | --- | --- |
| Bar modes | Compact, Clean Compact, Separated, Professional, Simple. Independent icon visibility/placement/spacing profiles. | `modules/bar/`, `modules/settings/pages/SettingsBarPage.qml`, `config/SettingsStore.qml` |
| Position and sizing | Top/Bottom/Left/Right bar, margins, monitor layout, icon spacing and alignment. | `modules/main/Bar.qml`, `modules/main/VerticalBarContent.qml`, bar settings pages |
| Primary controls | RusticQ menu, launcher, AI, editable menu bar, workspace buttons, Quick Modes, Quick Control. | `modules/main/ContextMenu.qml`, `components/QuickModes.qml`, `components/Workspaces.qml` |
| Status items | Weather, clock, calendar, network (Wi-Fi/Ethernet), Bluetooth, battery, audio, microphone and task access. | `components/`, `modules/bar/`, `modules/main/IndicatorPopup.qml` |
| Focused monitor | Launcher, Settings, and certain overlays follow Hyprland's focused monitor (see runtime limitations). | `shell.qml`, `config/Store.qml` |

## Windows and desktop

| Feature group | Features | Source |
| --- | --- | --- |
| App Launcher | Search, launch, app presentation and sizing. | `modules/main/LauncherOverlay.qml`, `modules/main/MiniLauncher.qml` |
| Dock | App shortcuts, running-app representation, auto-hide options. | `modules/main/RusticDock.qml`, `modules/settings/pages/SettingsDockPage.qml` |
| Desktop widgets | Clock, date/calendar, weather, hardware stats, media and connectivity cards. | `modules/main/DesktopWidgets.qml`, `modules/main/DesktopWidgetWindow.qml` |
| Monitoring | CPU/memory/disk/network graphs, process manager, task/dashboard views. | `modules/main/SystemMonitorWindow.qml`, `modules/main/SystemDashboard.qml`, `modules/process/` |
| Notifications | Toasts, history and presentation. | `modules/main/NotificationToasts.qml`, `services/NotificationCenter.qml` |
| Media and capture | Player cards, media controls; screenshots and screen recording when their tools are installed. | `modules/main/MiniAudio.qml`, `scripts/rustiq-capture.sh`, `scripts/rustiq-record.py` |
| AI workspace | Cloud AI and provider configuration, subject to separately configured credentials. | `modules/ai/`, `scripts/cloud_ai.py`, `modules/settings/pages/SettingsAIPage.qml` |

## Settings destinations

Appearance · Bar · Modules · Widgets · Dock · App Launcher · Displays · OS information · Hardware · Installed Apps · Storage · Arch Updater · Shortcuts · Integration · AI Providers · About.

- **Shortcuts:** inspect and override Omarchy/Hyprland Lua bindings, register RusticQ actions (including bar menus/popups and workspaces), keep line-specific backups, and revert individual managed shortcuts. See `SettingsShortcutsPage.qml` and `scripts/rustiq-desktop-integration.py`.
- **Integration — dependencies:** read-only package presence scan plus user-confirmed *optional* tool installation in a terminal. See `SettingsIntegrationPage.qml`, `scripts/rusticq-dependencies.py`, `config/dependencies.json`.
- **Integration — permanent shell:** separately protected Omarchy Quattro startup replacement, automatic backup and CLI/UI restore. Does not modify `/usr/share/omarchy`. See `scripts/rustiq-desktop-integration.py`.
- **System settings:** CPU/GPU/OS/storage inventory, Arch package lists and guarded package operations; some items depend on pacman, PolicyKit and hardware access.

## Requirements by feature

The **core shell** needs a running Hyprland Wayland session, Quickshell and Python; icon fallback also needs Material Symbols. Wi-Fi requires NetworkManager, Bluetooth requires BlueZ, screen capture uses Grim/Slurp, recording uses `wf-recorder`, and package updates use pacman-related tools. See [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) for the explicit install matrix.

## Feature and menu source index

- `modules/settings/pages/` — one settings page per functional area.
- `components/` — bar tiles, status icons, reusable controls.
- `services/` — shared QML adapters (no presentation code when avoidable).
- `scripts/` — command-line backend, shell integration, screenshots, recording, updater.
- `config/` — theme, persisted layout profiles and dependency allowlist.

A feature is **optional** if its helper can be missing while the shell starts. Installing a package alone does not activate services or enable hardware permissions.

## Beta 1 additions

- App Launcher: arrow keys to select, Enter to launch, mouse hover/click selects the same highlighted entry.
- Displays: one selected display editor with aligned mode chooser, drag preview, scale/position, validate/apply readback. Omarchy Lua runtime is preferred; output must verify before claiming applied.
- Installed Apps: Manage resolves owning pacman package conservatively; install/uninstall requires a separate confirmation overlay and interactive terminal.
- Modules: per-bar-layout visibility presets and copy tools live in Modules; redundant Icon preferences in Bar removed.
- Settings: persistent scrollbars for sidebar and content; the 1100×760 window size remains unchanged.
- Audio: compact popup margin, advanced real output and microphone peaks and a user-initiated quiet test tone.
- Remote installer: GitHub-hosted `scripts/install.sh` now bootstraps full source for `curl | bash` use once pushed to main.
