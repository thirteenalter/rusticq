# RusticQ architecture and feature locations

```
quickshell/
├── shell.qml                    # application entry and IPC actions
├── README.md                    # overview + quick start
├── FEATURES.md                  # feature-by-feature index
├── AGENTS.md                    # contributor guidance
├── COMPAT-0.3.1.md             # Quickshell API compatibility notes
├── assets/                      # icons, brand artwork; local fonts optional
├── config/
│   ├── Config.qml, Store.qml    # shell state and global action routing
│   ├── SettingsStore.qml        # persisted user preferences, profiles
│   ├── Theme.qml, Fonts.qml     # visual system
│   └── dependencies.json       # allowlisted Arch core/optional packages
├── components/                  # shared QML elements and bar icons
├── modules/
│   ├── bar/                     # alternate bar layouts and popups
│   ├── main/                    # launcher, dock, widgets, dashboards, windows
│   ├── quickcontrol/            # quick control cards
│   ├── power/                   # power controls
│   ├── ai/                      # AI workspace
│   ├── process/                 # process management
│   └── settings/
│       ├── SettingsWindow.qml  # 1100x760 floating settings and navigation
│       └── pages/              # Bar, Shortcuts, Integration, AI, etc.
├── services/                    # system service adapters; network, media, etc.
├── scripts/
│   ├── install.sh              # opt-in source install + core packages
│   ├── bootstrap.sh            # future HTTPS + checksum release bootstrap
│   ├── rusticq-dependencies.py # package diagnostics + safe optional installs
│   ├── rustiq-desktop-integration.py  # shortcut overrides + Omarchy backup/revert
│   └── ...                     # media, screen capture, updater, diagnostics
├── docs/                        # installation, dependencies, troubleshooting
├── changelog/                   # prior release details
└── tools/                       # regression tests and static checks
```

## How functionality flows

1. `shell.qml` creates the shell components. QML `Store`/`SettingsStore` hold application state and user preferences.
2. Views under `modules/` and `components/` render the UI; `services/` read system backends.
3. Actions requiring OS changes call purpose-built scripts in `scripts/`. Avoid arbitrary shell strings from QML.
4. `SettingsIntegrationPage.qml` calls two distinct backends:
   - `rusticq-dependencies.py` **status/launch** for package inventory and terminal-confirmed optional tools.
   - `rustiq-desktop-integration.py` for permanent Omarchy startup backup/enable/revert.
5. `config/dependencies.json` is the package allowlist consumed by UI and setup; it is **not** a command template.

## Stable directories to avoid accidental overwrites

- `~/.config/hypr/` — user compositor settings. Never touched by `install.sh`.
- `~/.local/share/rusticq/source/` — local source install made by `install.sh`.
- `~/.local/share/rusticq/shell/` — stable, separate copy used by explicit permanent integration.
- `~/.local/state/rusticq/setup-backups/` — source install upgrade backups.
- `~/.local/state/rusticq/integration/` — permanent Omarchy backup and shortcut revert state.

Do not interchange the last two backups: they restore different things.

Beta 1 includes `modules/main/PackageConfirmationWindow.qml` (separate confirmation layer) and `scripts/rustiq-audio-test.sh` (user-triggered quiet speaker test).
