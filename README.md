<div align="center">
  <img src="assets/rusticq-about-lockup.png" alt="RusticQ logo" width="390" />

  # RusticQ
  **A modular Quickshell desktop for Hyprland · Beta 1**

  A configurable Wayland bar, launcher, widgets, dock, shortcuts, and system settings.

  [Features](FEATURES.md) · [Installation](docs/INSTALLATION.md) · [Dependencies](docs/DEPENDENCIES.md) · [Structure](docs/PROJECT-STRUCTURE.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)
</div>

## Overview

RusticQ is a user-space desktop shell configuration built with **Quickshell/QML**, for **Hyprland on Arch Linux**, including compatible **Omarchy Quattro** installations. It does not replace your window manager. Beta 1 was developed against **Quickshell 0.3.1**; other releases require testing.

- **Bar:** Compact, Clean Compact, Separated, Professional and Simple layouts, Top/Bottom/Left/Right placement, per-layout icon visibility, icon order/placement and spacing.
- **Launcher & workspaces:** app search, launcher on the focused monitor, workspace navigation and assignable shortcuts.
- **Popups & controls:** connectivity, Bluetooth, battery, audio, clock/calendar, notifications, Quick Control and Quick Modes.
- **Extras:** optional desktop widgets, dock, media controls, system monitor, screenshots and recording.
- **Settings:** appearance, live displays, apps, updates, shortcuts, AI providers and reversible Omarchy integration.

Detailed module and feature inventory: **[FEATURES.md](FEATURES.md)**.

## Beta 1 — live Displays and floating confirmations

- **Settings → Displays**: selecting a resolution/refresh rate, scale, relative position, or releasing a monitor after dragging applies to the **current Hyprland session immediately**. RusticQ reads back the effective values. Press **Keep changes** within 15 seconds; otherwise an independent Python watchdog tries to restore the prior arrangement even if Quickshell exits. If applying fails, the helper attempts an immediate rollback. The screen settings are **not saved to Omarchy at startup** unless you separately export and source the generated Lua monitor rules.
- **Confirmation window**: install/uninstall confirmations use a compact floating window, not a full-screen layer overlay. A Hyprland helper finds RusticQ Settings and the confirmation by their exact titles/addresses, then places the confirmation on the **same workspace** (including when Settings is on the second monitor).
- This implements the live-apply and safety approach described by [HyprMon](https://github.com/erans/hyprmon), adapted for RusticQ's QML Settings and Lua-capable Omarchy Quattro; no HyprMon dependency is needed.

If a display change produces a blank image, **wait 15 seconds** rather than confirming it. From a still-visible terminal you may run `python3 scripts/rustiq-display.py revert`. A separate logout/login will use your persistent Hyprland monitor configuration, since live changes are session-only.

## Beta 1 feature audit — stability and productivity batch

This source includes **System Doctor** and private JSON snapshots in **Settings → Integration**, a guarded `rusticq` CLI, an optional crash-restart user unit, and a calculator in the existing launcher (`=sqrt(144)+8`; Enter to copy if `wl-copy` is installed).

Use `python3 scripts/rusticq-cli.py doctor` without installing anything. Once installed via `scripts/install.sh`, use `rusticq doctor`, `rusticq status`, `rusticq config backup settings`, or `rusticq watchdog status`. Bare `rusticq` still launches the shell. The watchdog unit is **not enabled** automatically; never enable another shell while Omarchy's own startup manages RusticQ.

This is a **verified offline feature batch**, not a claim that all 50 feature requests are complete. See [Beta 1 audit](docs/audit/BETA1-REPORT.md) and [50-feature matrix](docs/audit/BETA1-50-FEATURE-MATRIX.csv). Live Hyprland and performance testing are still required.

## Beta 1 Phase 2 — Launcher Tools & Reliability

This is an incremental **major productivity update** on top of Beta 1 Phase 1. The same App Launcher and system services are reused (no second launcher, media daemon or wallpaper manager).

| Launcher input | Action |
| --- | --- |
| `:settings display` | Find and open the Displays settings page. |
| `:emoji cat` | Search the built-in emoji catalog, then choose an entry to copy it. |
| `:wallpaper sunset` | Search images in personal Wallpapers/Pictures directories and apply a selected image with your running `swww`, `awww` or `hyprpaper` backend. |
| `:color` | Close launcher, launch local `hyprpicker`, copy HEX and report HEX/RGB/HSL. |
| `:ocr` | Close launcher, select a region, run local `tesseract` OCR, copy recognized text. No network transmission. |
| `=5 km to mi` | Convert compatible units with the safe calculator (length, mass, volume, duration, temperature). |
| `firefx` | Typo-tolerant app search with prefix and usage ranking. |

Search commands appear as separate launcher results and use the same **Up/Down/Enter** interaction as installed applications. Color and OCR invoke tools only after you select their explicit action; they run after the launcher overlay closes. Optional dependencies are visible in **Settings → Integration**, not force-installed on startup.

**Release engineering:** `python3 tools/build-release.py --out /tmp/rusticq-dist --previous old-full.zip` produces deterministic full + incremental patch ZIPs and a SHA256SUMS file. `.github/workflows/static-validation.yml` runs offline source validation on CI. This does not mean live Hyprland APIs or AUR/Nix packaging have been verified.

See [Phase 2 audit](docs/audit/BETA1-PHASE2-REPORT.md) for features, remaining gaps and test evidence.

## Beta 1 Phase 3 — Universal Launcher, Notes & Desktop Profiles

This batch extends **existing components** and reuses Quickshell's PipeWire and notification services. It does not enable new background daemons or replace Omarchy's lock, idle or authorization agents.

| Use | Command / location |
| --- | --- |
| Local file search | `:files report` · user Documents/Downloads/Desktop/Pictures/Music/Videos; hidden files excluded |
| Folder search | `:folders projects` · select to open in file manager |
| Open window | `:windows browser` · Hyprland client focus only after explicit selection |
| Jump workspace | `:workspaces 2` · uses the current Hyprland workspace list |
| Create note | `:notes +Buy milk` · select Add to save privately |
| Move note between columns | `:notes milk` then select the note, or Settings → Notes & Kanban |
| Notes CLI | `python3 scripts/rusticq-cli.py notes list` / `notes add "Task"` |
| Per-application audio | Audio → Advanced → Application audio mixer; active PipeWire streams only |
| Group notifications | Notifications → Grouped by application → Show/Hide per app |
| Desktop presets | Settings → Modules → Desktop profiles → Gaming/Coding/Battery/Presentation/Restore |

Notes are stored in `~/.local/state/rusticq/notes.json` with owner-only permissions. Audio controls appear only when a playback stream exists; hidden settings do not trigger a polling process. Desktop presets affect only RusticQ UI settings, **not system power management, security or Omarchy startup**.

This is not a 50/50 completion claim. High-risk requests such as PAM/FIDO2, Polkit, sensitive clipboard history, cloud screen upload and privileged session replacement cannot be considered production-ready without their proper security integrations and real compositor tests. Consult the [Phase 3 audit](docs/audit/BETA1-PHASE3-REPORT.md) and [updated matrix](docs/audit/BETA1-50-FEATURE-MATRIX.csv).

## Phase 4 — desktop widgets and live bar icon ordering

- **Desktop Scratchpad:** turn on **Settings → Widgets → Notes widget**, then write unrestricted multiline text. It autosaves in `user-settings.json` independently for each **monitor and workspace**. The old task notes remain accessible from Settings → Notes & Kanban; scratchpad text is intentionally a separate document, not a Kanban task.
- **Desktop Kanban:** turn on **Kanban widget** to see To Do / Doing / Done lanes. Click or type in the widget (keyboard focus is enabled); **Next →** moves tasks through stages. Task data remains shared with Settings → Notes & Kanban.
- **Random Image:** turn on **Random image widget**, choose a local folder in Settings → Widgets, and use **Next ↻** or an optional 1/5/15-minute rotation. The picker never uploads images, follows symlinks or recursively scans your filesystem. The default folder is `~/Pictures/Wallpapers`.
- **Bar reorder:** in **Settings → Bar → Icon spacing & drag ordering**, drop **between** icons to insert (others shift; accent caret), or drop **on the center** of a card to swap the two icons (accent tile with `↔ Swap`). Cross-zone moves work in both modes. Use the small **‹ / ›** buttons for precise moves. Each layout (Simple, Compact, Clean Compact, Separated, Professional) retains its own order and spacing; Reset mode restores its original icon positions/order.
- All three desktop widgets use the existing bottom-layer draggable per-monitor surfaces. New widgets are **disabled by default**, so upgrading does not add resource usage until explicitly enabled.

## Latest Beta 1 hotfix: power overlay and multi-provider search

- The System/Power menu uses the original monitor-scoped `PanelWindow` Wayland **Overlay** layer (not a compositor `FloatingWindow`), with keyboard navigation and confirmation.
- Installed Apps search combines Pacman, Yay/AUR and Flatpak with per-provider status. Results are parsed from each tool's native CLI output; Flatpak requests full untruncated application IDs. A slow provider does not block completed results from the others.
- Searching is read-only. Package installation/removal still requires explicit GUI confirmation and provider authorization.

See [`changelog/BETA1-POWER-OVERLAY-PACKAGE-SEARCH-HOTFIX.md`](changelog/BETA1-POWER-OVERLAY-PACKAGE-SEARCH-HOTFIX.md).

## Pacman / Yay / Flatpak search reliability

- Search from Settings → Installed apps uses `yay -Ss <query>` exactly as it does in a terminal, with ANSI escaping handled by the parser. AUR items such as `ventoy-bin` should show in Yay/AUR even if a Flatpak remote times out.
- Provider searches remain isolated: Flatpak timeouts are displayed as an individual provider warning, without hiding Pacman or Yay results.
- The power menu remains a full-screen Wayland Overlay layer, with a centered card using the same `Theme.sectionRadius` and `Theme.borderaccent` as the launcher. Click outside the card or press Esc to close; the small X button was removed.
- If AUR results are still absent, run `python3 scripts/rustiq-package-manager.py search-source yay ventoy-bin` and compare with `yay -Ss ventoy-bin` to inspect the actual JSON response.

## Quick start

### 1. Try Beta 1 without installing anything

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

Open **Settings → Integration → Required & optional dependencies**, select a missing tool, type `INSTALL`, then approve the operation through the desktop Polkit authorization dialog. Reading the page only inspects installed pacman packages; it never installs packages automatically. Examples: Bluetooth, Wi-Fi, recording, screenshots, media playback, night light, and package-update tools.

**Permanent Omarchy replacement is a different action below this section.** It requires Omarchy Quattro detection, a backup, and the explicit confirmation phrase `ENABLE RUSTICQ`. The default user-local setup leaves it off.

## One-line installation from GitHub

After merging this Beta 1 release into `thirteenalter/rusticq` **main**, the canonical installer URL is:

```bash
curl -fsSL https://raw.githubusercontent.com/thirteenalter/rusticq/refs/heads/main/scripts/install.sh | bash
```

The script downloads the full repository from GitHub over HTTPS, validates the ZIP entries, installs missing **core** packages on Arch/Omarchy (with sudo confirmation), backs up an existing user-local RusticQ source install, and creates `~/.local/bin/rusticq`. It **does not** replace Omarchy permanently or alter Hyprland autostart. Optional feature dependencies are managed in Settings → Integration.

For a review-first flow (recommended for a remote script):

```bash
curl -fsSLo /tmp/rusticq-install.sh https://raw.githubusercontent.com/thirteenalter/rusticq/refs/heads/main/scripts/install.sh
less /tmp/rusticq-install.sh
bash /tmp/rusticq-install.sh
```

The `main` branch can change. For pinned, reproducible installations, use the SHA-256 verified `scripts/bootstrap.sh` with a published full-release ZIP. **The remote curl command runs the code currently on GitHub, not changes that exist only in your local ZIP.**

## Update from ZIPs

Every release provides two archives:

| Archive | Use |
| --- | --- |
| **Full build** | Entire `quickshell/` source directory, suitable for a fresh extraction. |
| **Patch** | Only changed/new files, with the same `quickshell/` paths. Extract over the matching Beta 1 base. |

Example for a patch downloaded locally:

```bash
unzip -o rusticq-beta1-patch.zip -d ~/dev
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

A failed optional install is not proof that RusticQ was installed or activated. Review the status shown in Settings. If you have changed Omarchy startup and cannot log in, use the [TTY recovery procedure](docs/TROUBLESHOOTING.md).

## Beta 1 Phase 4 — Widget interaction & icon swap hotfix

- In **Settings → Bar → Drag to reorder**, dragging icon A over icon B swaps **both icons' positions**; cross-zone swaps also exchange their Left/Center/Right assignments. Empty-zone drops still append. Profiles are independent for Compact, Clean Compact, Separated, Professional and Simple.
- In **Settings → Widgets → Widget workspaces**, select workspace 1–10 for Notes, Kanban and Random Image. Defaults are workspace 1 only for these interactive widgets. Selection applies per monitor based on its active Hyprland workspace, not the global focused workspace. Unchecked workspaces show no corresponding widget.
- **Notes widget** is a free-form multiline scratchpad, saved per monitor/workspace; switch workspace for a different page. Earlier Kanban tasks remain in their existing database. Kanban data continues to be shared between Settings and the widget (workspace-specific *visibility*, not separate task databases).
- Drag interactive widgets using the **small top-right grip**, not the entire header. Use the **bottom-right grip to resize**; dimensions and positions are stored per monitor/workspace. Interactive widgets accept keyboard focus on their Bottom-layer window.
- Existing configs remain readable; new workspace/widget-size fields are optional. No new system dependency or background daemon is added.

## Beta 1 Phase 4 — Dual drag targets (insert + swap)

In Settings → Bar, **two gestures coexist** without a new mode toggle: move a dragged card into a **gap or the outer edge of another card** to see the vertical accent insertion caret, then release to insert while other icons shift. Hover the **middle of another icon card** to see the highlighted **↔ Swap** target, then release to exchange their positions. Both gestures work within or across Left/Center/Right and save to the active bar layout only. No other profile or desktop widgets are changed.

## GUI package transactions and safe Omarchy backup

**Settings → Installed Apps** supports installing official Arch repository packages and removing installed pacman packages with a separate floating confirmation window. **Settings → Integration → Dependencies** supports adding and removing *optional* packages; RusticQ core requirements cannot be removed there. Transactions run directly from GUI via graphical Polkit authorization (`pkexec /usr/bin/pacman`), never by running user-editable Python as root or launching a terminal. The operation result is shown in Settings. Protected boot/session packages cannot be removed in the GUI. On Arch, installation can perform a full upgrade. On Omarchy, its pacman guards remain in force: unsupported direct operations may be rejected rather than bypassed. A working graphical Polkit agent is mandatory. AUR, Flatpak, and AppImage removal are not claimed to be supported.

**Permanent Integration** automatically captures and verifies Omarchy's default Hyprland Lua plus the existing `~/.config/hypr`, `~/.config/omarchy`, and `~/.config/quickshell` trees before changing startup. The originals are saved privately under `~/.local/state/rusticq/integration/backup/`. On revert, only RusticQ-managed files are restored and current managed configs are archived in `revert-history/`; unrelated user files are not overwritten. A Verify Backup button checks integrity. See [docs/INSTALLATION.md](docs/INSTALLATION.md).

## GUI Apps search and power menu (Beta 1)

**Settings → Installed Apps** now searches **Pacman, Yay/AUR, and Flatpak** together, with source filters and graphical install/remove confirmations. Pacman uses Polkit, AUR builds run under the normal user with Yay, and Flatpak uses its native system/user authorization. All providers are optional except the existing Arch package base; an absent provider is skipped with an availability indicator. Review any AUR PKGBUILD before approving installation.

**Shell → Power menu** opens a centered overlay on the focused monitor. Use ↑/↓ or 1–6 to navigate, Enter to select, Enter again to confirm, Esc to close. Actions: Screensaver, Lock, Suspend, Logout, Reboot and Shutdown. You can bind the registered `power` action under Settings → Shortcuts or use the IPC `rusticq power`. The power menu performs nothing on its own until explicitly confirmed.

For backend limitations and dependencies, see `docs/DEPENDENCIES.md`.

## RusticQ Native Lock Screen (Beta 1)

**Power Menu → Lock** now launches an independent Quickshell configuration with `WlSessionLock` for real Wayland session locking and `PamContext` for PAM login authentication. RusticQ's clock, accents and password card are native QML; the main desktop shell does not need to stay alive for authentication.

- Appearance → RusticQ Lock Screen: choose **Solid** or **Current Wallpaper** and check native prerequisites without locking.
- Run `python3 scripts/rusticq-native-lock.py prepare` to check requirements; **Lock now** then starts the real locker.
- Keyboard Shortcut Manager and `qs ipc call rusticq lock` also start the native locker.
- Screensaver remains Omarchy's ASCII screensaver, separate from Lock.
- Hyprlock is an optional explicit fallback via `python3 scripts/rusticq-native-lock.py legacy`, **not** automatically launched if native locking fails.
- The native locker can leave your session locked if its process crashes. Read [docs/LOCKSCREEN.md](docs/LOCKSCREEN.md) and test only with TTY recovery access before relying on it.


### Keyboard navigation for the Shell Menu Bar

Open **File / Edit / View / Share / Shell / Tools** by clicking its bar label or using an existing RusticQ menu shortcut. With the menu popover focused, press **Left / Right** to cycle enabled menu categories, **Up / Down** to select an action, **Enter / Space** to activate it and **Escape** to close it. The selected row is highlighted and longer menus scroll to keep the selection visible. These keys only belong to the open menu and are not global keybindings.

### Automatic shortcut safety snapshots

Before changing or restoring any shortcut, RusticQ now privately archives the complete installed Omarchy defaults (once) and a fresh snapshot of `~/.config/hypr` plus relevant desktop/shell dotfiles (every operation). Changes are blocked if backup verification fails. Settings → Shortcuts displays the snapshot status and offers **Verify backup**. See [docs/AUTOMATIC-OMARCHY-SHORTCUT-BACKUPS.md](docs/AUTOMATIC-OMARCHY-SHORTCUT-BACKUPS.md).

### Shortcuts: confirmed automatic Omarchy backups

In Settings → Shortcuts, **Apply override** now opens a floating confirmation on the Settings workspace. **Back up & continue** creates verified snapshots of the complete installed Omarchy default tree (once) and selected Hyprland/dotfiles trees (before each shortcut change), then applies the requested binding. **Create backup now** does not edit bindings; **Verify backup** remains available even with zero snapshots and explains that state. See `docs/AUTOMATIC-OMARCHY-SHORTCUT-BACKUPS.md`.

### RusticQ Beta 1 authoritative basecode — swaybg / Toggle Bar

The Beta 1 source archive remains the canonical foundation. Wallpaper can use **swaybg Low Memory** in Settings → Appearance → Wallpaper; the existing `rusticq-idle-memory.py` provides Set baseline and Measure RAM. **Settings → Modules** has opt-in Low Memory Shell Mode. **Settings → Bar** offers Show/Hide, and **Settings → Shortcuts** can register `bar-toggle`, `bar-show`, or `bar-hide` while preserving backup of Omarchy bindings. When hidden, the bar retains a floating restore handle on each screen. Existing workspace widget settings, Native Lock, Wi-Fi QR, Notifications, and integration are preserved. See `docs/WALLPAPER-LOW-MEMORY.md`.

### Updating an installed RusticQ shell

**Settings → Integration → Shell Updates** supports confirmed **Reapply Local**
from `~/dev/quickshell`, GitHub Release **Check / Update Shell** with verified
full ZIP assets, and **Rollback Shell**. It preserves the old shell at
`~/.local/share/rusticq/shell-before-update-*` and existing user settings.
These shell updates are **separate from Omarchy/pacman upgrades** and take
effect in a newly started Quickshell session. See
[docs/SHELL-UPDATES.md](docs/SHELL-UPDATES.md).

### System OSD — volume, brightness and touchpad

RusticQ now has a lightweight on-screen popup for PipeWire speaker volume and mute, microphone mute, sysfs screen brightness, and keyboard backlight. The overlay is non-focusable, auto-hides, and appears on the focused monitor. Settings → Modules provides **Show system OSD** and **Preview OSD**. Shortcut actions allow changing screen/keyboard brightness and toggling a detected touchpad (USB mouse is never disabled); see [System OSD documentation](docs/SYSTEM-OSD-HARDWARE.md). No Omarchy default shortcuts are changed automatically.

### Transfer user settings between RusticQ installations

Settings → Integration → **User settings · Save / Load** can export your
current `user-settings.json` as a portable JSON file and import an existing
export or plain legacy settings file. Imports require validation, a typed
confirmation and an automatic original-configuration snapshot before applying.
**Restart RusticQ after importing.** See
[User Settings Transfer](docs/USER-SETTINGS-TRANSFER.md).
