# RusticQ — Feature inventory

This is a **functional map of the current source**, not a promise that every module works on every machine. Entries below link to the relevant implementation directories.

## Launcher Studio

- Refined legacy header/search alignment; Launchpad and Overview search surfaces
  with a clear placeholder; Overview shortcuts collapse when empty.
- Shared content inset ownership across panels and popups. **Appearance → Surface
  Spacing** offers persisted pixel controls, live preview, per-control Auto and
  reset. Bar/launcher custom padding remains independent.
- Wi-Fi uses a connection subtitle, accessible power toggle, search, quiet network
  rows with connection indicators and advanced navigation in its footer.

- Eleven real presentations, including both legacy layouts and Detached Floating
  Search, use one native application model and shared safe search/providers.
- Spotlight/Compact Command start search-only; Launchpad/Overview offer real icon
  grids; Raycast provides command actions; Fluent pins/recents; Classic categories;
  Minimal is lightweight. Detached has two independent surfaces and a clear gap.
- Live style gallery uses actual frontends. Shared and layout-specific geometry,
  position, RAGE material, visibility, backdrop and existing motion controls persist.
- None creates no fullscreen window; optional native blur/dimming is separately
  scoped. Real keyboard, provider, migration, geometry and palette regression tests,
  native screenshots and pixel comparisons are included.
- [Implementation, screenshots and limitations](docs/LAUNCHER-STUDIO.md) ·
  [validated settings schema](docs/LAUNCHER-STUDIO-SCHEMA.md).

## RAGE — RUSTIQ ADAPTIVE GLASS ENGINE

- Optional global glass in Appearance; disabled by default, live bindings and
  persistent settings, with Frosted, Crystal and Tinted presets. Standard opaque
  palette tokens and the existing Aether watcher remain intact.
- Exclusive selects one independent native provider for all semantic colors,
  including solid surfaces; Obsidian, Pearl, Pure Crystal and Graphite Frost.
  Adaptive preserves the saved Gruvbox/Aether preferences. Material, provider,
  geometry and decorative visibility are independent.
- One translucent outer material, 3–6.5% nested overlays, restrained edge lighting
  and shared text contrast protection. Hyprland typed boolean blur detection is
  verified; native pixel comparisons distinguish real blur from transparency.
- Shared window, primary, secondary, card, control, hover, pressed, selected,
  popup, tooltip, border, highlight, shadow, modal and authentication tokens.
- Covers bar, dock, launcher, Quick Control, Settings/device pages, notifications,
  popups, desktop widgets, utilities, AI and secure authentication views.
- Bar Surface Styling: independent outer/segment/module backgrounds and outlines,
  six quick presets, live preview, per-bar glass opt-out, opacity multiplier,
  independent radii and optional capsules. All five modes and four edges; no
  geometry or input-region changes when decoration is hidden. Professional keeps
  the original full-rail structure. Separated has no implicit enclosing frame.
- Audited Hyprland Lua named session rules, alpha-aware bar blur and independent
  popup blur. No global blur changes, config writes, reloads or new dependencies.
  Niri, legacy/unknown Hyprland and unavailable IPC use tinted fallback.
- Performance/low-memory modes release reflection/shading resources and disable
  RAGE blur without changing saved preferences. Crystal has no optical refraction.
- See [architecture, schema and validation](docs/RAGE.md),
  [surface audit](docs/audit/RAGE-SURFACES.md) and [changelog](changelog/RAGE.md).

## Shell and bar

| Feature group | Features | Source |
| --- | --- | --- |
| Bar modes | Compact, Clean Compact, Separated, Professional, Simple. Independent icon visibility/placement/spacing/order profiles with drag-and-drop reordering. | `modules/bar/`, `modules/settings/pages/SettingsBarPage.qml`, `config/SettingsStore.qml` |
| Position and sizing | Top/Bottom/Left/Right bar, margins, monitor layout, icon spacing and alignment. | `modules/main/Bar.qml`, `modules/main/VerticalBarContent.qml`, bar settings pages |
| Primary controls | RusticQ menu, launcher, AI, editable menu bar, workspace buttons, Quick Modes, Quick Control. | `modules/main/ContextMenu.qml`, `components/QuickModes.qml`, `components/Workspaces.qml` |
| Status items | Weather, clock, calendar, network (Wi-Fi/Ethernet), Bluetooth, battery, audio, microphone and task access. | `components/`, `modules/bar/`, `modules/main/IndicatorPopup.qml` |
| Popup interaction | Click to open, or optional persistent hover opening under Bar settings. Pointer exit keeps the panel open; outside clicks dismiss it. The popup owns keyboard input independently of the bar. | `components/BarZone.qml`, `modules/main/IndicatorPopup.qml` |
| Weather data | Validated Celsius observations and nearest reported city, last-known data on network failure, refresh status and a scrolling details popup. IP-based location can be affected by a VPN. | `services/WeatherService.qml`, `modules/main/MiniWeather.qml` |
| Focused monitor | Launcher, Settings, and certain overlays follow Hyprland's focused monitor (see runtime limitations). | `shell.qml`, `config/Store.qml` |

## Windows and desktop

| Feature group | Features | Source |
| --- | --- | --- |
| App Launcher | Search, launch, app presentation and sizing. | `modules/main/LauncherOverlay.qml`, `modules/main/MiniLauncher.qml` |
| Dock | App shortcuts, running-app representation, auto-hide options. | `modules/main/RusticDock.qml`, `modules/settings/pages/SettingsDockPage.qml` |
| Desktop widgets | Clock, date/calendar, weather, hardware stats, media, connectivity, Notes, Kanban and locally randomized photo cards. | `modules/main/DesktopWidgets.qml`, `modules/main/DesktopWidgetWindow.qml` |
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

## Beta 1 Phase 2 — Integrated Launcher Tools

- `:settings QUERY` — search existing RusticQ Settings destinations. Uses the existing `Store.showSettings` navigation.
- `:emoji QUERY` — bounded local emoji/symbol catalog, optional `wl-clipboard` for selected copy.
- `:wallpaper QUERY` — read-only local image search under `$HOME/Pictures` and wallpaper subdirectories. Selecting an image invokes the existing wallpaper service. No automatic indexing or wallpaper edits while searching.
- `:color` — explicitly launched `hyprpicker`, copies validated HEX to clipboard, displays RGB/HSL breakdown in optional notification.
- `:ocr` — explicitly selected region; `slurp → grim → tesseract → wl-copy` with no cloud APIs, history or background OCR.
- `=NUMBER UNIT to UNIT` — dimensional unit conversion with a fixed safe conversion table.
- Typo-tolerant application name search, preserving existing usage/pinned ranking for ties.
- Feature-specific optional dependencies appear in Integration; builds are reproducible source archives using `tools/build-release.py`.

The emoji catalog is not the full Unicode database, wallpaper listing is textual rather than thumbnails, and runtime Wayland tests still require the target desktop.

## Beta 1 Phase 3 — Additional functional components

- Local-only file/folder launcher providers, Hyprland live window/workspace search/focus.
- Private, atomic Notes & Kanban backend (`scripts/rusticq-notes.py`), Settings task board and launcher commands.
- Native stream-level PipeWire mixer within existing Advanced Audio (lazy binding).
- On-demand group-by-app display for the existing notification history, expandable without losing original actions.
- Desktop UI profiles (Gaming/Coding/Battery/Presentation) with restore previous in Modules.

See `docs/audit/BETA1-PHASE3-REPORT.md` for feature status, limitations, conflicts and live tests.

## Phase 4 widget + icon editor extensions

- `modules/main/DesktopNotesCard.qml` — shared notes.json board/list, active only when desktop Notes or Kanban enabled; no new daemon.
- `modules/main/DesktopRandomImageCard.qml` — local-only image slideshow (manual and optional timed rotation).
- `scripts/rusticq-widget-images.py` — safe bounded image chooser, symlink rejection and home-directory restriction.
- `modules/settings/pages/BarAlignmentEditor.qml` — drag-and-drop icon tiles with precise move controls in the **Icon spacing** section; `SettingsStore.barIconOrderByMode` is read by `components/BarZone.qml`.
- The global appearance/theme, Quick Modes and keyboard bindings are unchanged; all widget toggles default to off.
