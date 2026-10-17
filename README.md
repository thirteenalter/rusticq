<div align="center">
  <img src="assets/rusticq-about-lockup.png" alt="RusticQ logo" width="390" />

  # RusticQ
  **A modular Quickshell desktop for Hyprland · Alpha 4 RC5**

  A configurable Wayland bar, launcher, widgets, dock, shortcuts, and system settings.

  [Features](FEATURES.md) · [Installation](docs/INSTALLATION.md) · [Dependencies](docs/DEPENDENCIES.md) · [Structure](docs/PROJECT-STRUCTURE.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)
</div>

## Overview

RusticQ is a user-space desktop shell configuration built with **Quickshell/QML**, for **Hyprland on Arch Linux**, including compatible **Omarchy Quattro** installations. It does not replace your window manager. RC5 was developed against **Quickshell 0.3.1**; other releases require testing.

- **Bar:** Compact, Clean Compact, Separated, Professional and Simple layouts, Top/Bottom/Left/Right placement, per-layout icon visibility, icon order/placement and spacing.
- **Launcher & workspaces:** app search, launcher on the focused monitor, workspace navigation and assignable shortcuts.
- **Popups & controls:** connectivity, Bluetooth, battery, audio, clock/calendar, notifications, Quick Control and Quick Modes.
- **Extras:** optional desktop widgets, dock, media controls, system monitor, screenshots and recording.
- **Settings:** appearance, devices, apps, updates, shortcuts, AI providers and reversible Omarchy integration.

Detailed module and feature inventory: **[FEATURES.md](FEATURES.md)**.

## Quick start

### 1. Try RC5 without installing anything

A working Hyprland/Wayland session and Quickshell are required:

```bash
cd ~/dev/quickshell                # folder containing shell.qml
qs -p .
```

### 2. Install to your user account (recommended)

On Arch/Omarchy, from this **full source** directory:

```bash
bash scripts/install.sh --dry-run   # inspect the plan
bash scripts/install.sh             # install missing core packages; then copy the shell
~/.local/bin/rusticq                # launch, without replacing Omarchy
```

The setup installs *only missing core packages* from configured pacman repositories with interactive sudo approval. It does **not** start or enable services, overwrite `~/.config/hypr`, change your active shell startup, or enable permanent integration. Existing RusticQ source installs are saved under `~/.local/state/rusticq/setup-backups/` before an upgrade.

For offline setup or if packages are already managed separately:

```bash
bash scripts/install.sh --skip-deps
```

[Full installation and rollback guide →](docs/INSTALLATION.md)

### 3. Optional integrations

Open **Settings → Integration → Required & optional dependencies**, select a missing tool, type `INSTALL`, then approve the package operation in the terminal. Reading the page only checks `pacman -Q`; it never installs packages automatically. Examples: Bluetooth, Wi-Fi, recording, screenshots, media playback, night light, and package-update tools.

**Permanent Omarchy replacement is a different action below this section.** It requires Omarchy Quattro detection, a backup, and the explicit confirmation phrase `ENABLE RUSTICQ`. The default user-local setup leaves it off.

## Planned `curl` setup

A verified HTTPS release and public hosting **have not been configured**. The repository includes `scripts/bootstrap.sh`, ready to publish with the full build. Once a real release URL and its SHA-256 are available, the supported workflow will be:

```bash
curl -fsSLo bootstrap.sh "<PUBLISHED_BOOTSTRAP_HTTPS_URL>"
# Review bootstrap.sh before running it.
bash bootstrap.sh --url "<PUBLISHED_FULL_ZIP_HTTPS_URL>" --sha256 "<64_HEX_SHA256_FROM_RELEASE>"
```

`bootstrap.sh` requires HTTPS, checks the supplied SHA-256, rejects unsafe ZIP entries, and then uses `scripts/install.sh`. The placeholders above are intentionally **not live links**. Never use a random unverified `curl | bash` command.

## Update from ZIPs

Every release provides two archives:

| Archive | Use |
| --- | --- |
| **Full build** | Entire `quickshell/` source directory, suitable for a fresh extraction. |
| **Patch** | Only changed/new files, with the same `quickshell/` paths. Extract over the matching RC5 base. |

Example for a patch downloaded locally:

```bash
unzip -o rusticq-alpha4-rc5-setup-patch.zip -d ~/dev
cd ~/dev/quickshell
qs -p .
```

The ZIP itself contains no installer that runs on extraction. Only run `install.sh` when you explicitly want an additional user-local installation at `~/.local/share/rusticq/source`. That installation is **separate** from your development folder.

## Safety and portability

- **Arch-based systems** are supported for automatic pacman dependency installation; other Linux distributions require manual setup and are not claimed as tested.
- No default Omarchy package files under `/usr/share/omarchy` are modified by setup. Permanent integration is reversible, but desktop replacement can disrupt a session; test first.
- The full ZIP does not bundle proprietary/third-party font binaries. The installer adds the official Arch **Material Symbols** font package for icon fallback. Optional Poppins `.ttf` files can be placed in `assets/` if you have them and their licenses permit it; otherwise the UI uses a system sans font.
- Apps, power, audio, and network features require corresponding running desktop services; merely installing packages does not turn them on.
- Not all optional features are tested on all hardware. See [dependencies](docs/DEPENDENCIES.md) and [troubleshooting](docs/TROUBLESHOOTING.md).

## Developer map

| Path | Role |
| --- | --- |
| `shell.qml` | Shell entry point and cross-module action routing. |
| `modules/bar/`, `modules/main/` | Bar, overlay, launcher, dock, widgets, popup windows. |
| `modules/settings/` | Settings window and independent pages. |
| `components/` | Shared Material-style QML controls. |
| `config/` | Persistent settings, theme, typography, allowlisted dependencies. |
| `services/` | QML system adapters (network, battery, media, notifications). |
| `scripts/` | Safe Python/shell helpers, setup, diagnostics and integration. |
| `tools/` | Regression tests and static validation. |
| `changelog/` | Historical release notes and fixes. |
| `docs/` | Setup, dependency matrix, project structure and recovery. |

For details, see [PROJECT-STRUCTURE.md](docs/PROJECT-STRUCTURE.md) and [COMPAT-0.3.1.md](COMPAT-0.3.1.md).

## Troubleshooting

```bash
quickshell --version
qs -p .
qs log -f
python3 scripts/rusticq-dependencies.py status
```

A failed optional install is not proof that RusticQ was installed or activated. Review its terminal output. If you have changed Omarchy startup and cannot log in, use the [TTY recovery procedure](docs/TROUBLESHOOTING.md).
