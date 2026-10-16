# RusticQ Alpha 4 — RC1

**Baseline:** Alpha 4 spacing-editor fix. **Target:** Quickshell 0.3.1, Hyprland, Arch Linux. Original Gruvbox / Follow Aether design system, fonts and bar modes are preserved.

## New Settings sidebar categories

The left Settings navigation now scrolls independently and includes:

- **OS information**: distro, kernel, architecture, host, desktop session, locale and uptime.
- **Hardware**: CPU model and logical threads, RAM, GPU (via `lspci` if present), DMI vendor/model/board, BIOS and thermal zones.
- **Installed apps**: graphical desktop entries with themed icons, plus a searchable pacman package inventory with explicit / foreign counts.
- **Storage**: root filesystem used/free/capacity, disks and partitions from `lsblk`, journal and user-cache estimates.
- **Arch Updater**: safe repository update check, available package list, two-step confirmation, graphical PolicyKit authentication, persistent progress and terminal output.

Existing Appearance, Bar, Modules, Widgets, Dock, Displays, AI Providers and About pages remain independent and accessible. Search includes the new pages.

## Arch Updater details

**Check updates** executes `checkupdates --nocolor` (from `pacman-contrib`). It does **not** synchronize the live pacman database or install anything. `checkupdates` exit code `2` means no available updates. It never automatically checks or installs when the page loads.

**Install all updates** must be clicked explicitly, then confirmed in a second UI card. It starts a detached Python supervisor that invokes the fixed command:

```bash
pkexec /usr/bin/pacman -Syu --noconfirm --color never
```

This command is **real** and runs with root privileges after a graphical PolicyKit authorization. `--noconfirm` means pacman uses its default responses to questions, so the user is asked to approve the *entire full upgrade* in RusticQ. Users who want to review pacman questions interactively should instead run `sudo pacman -Syu` in their terminal. In all cases, back up important data and check [Arch Linux news](https://archlinux.org/news/) before a significant upgrade.

The supervisor is detached so that navigating away from Settings, closing it or reloading Quickshell does **not** send a termination signal to pacman. Do **not** reboot/power off while updating.

Status and full terminal output are written under `${XDG_STATE_HOME:-~/.local/state}/rustiq/updater/` (not to the user's shell settings). The Settings panel polls the status and displays the newest 180 log lines, including package downloads, installation and hooks. Errors and refusal of PolicyKit authorization are shown, never reported as success.

**Limitations:** `pkexec` requires a running graphical polkit agent; `checkupdates` requires `pacman-contrib`. AUR-built packages are only listed as foreign packages and are not upgraded here. Pacman downloads may show indeterminate rather than percentage progress depending on output format. Root operations can still fail because of package conflicts, manual interventions, networking, expired keyrings or `.pacnew` files.

## Dependencies on Arch

```bash
sudo pacman -S pacman-contrib pciutils
```

`pacman`, `python3`, `lsblk`, `df` are standard dependencies in a typical Arch installation. The updater also uses the `pkexec` executable from polkit and a graphical authentication agent. These must be available for installation mode. The other diagnostic pages are read-only and fall back gracefully if a tool is missing.

## Validation

- `python3 tools/verify-static.py` — QML braces/imports/known object-separator error patterns.
- `python3 tools/test_alpha4_rc1.py` — read-only system helper, mock update list and no-updates case, simulated persisted update status, sidebar routes.
- `python3 tools/test_alpha4.py` — Alpha 4 source regression.
- `python3 tools/test_bar_spacing.py` — editor spacing regression.
- Python compile checks for both helpers.
- Font coverage check against bundled `assets/google.ttf`.

**Not tested in build environment:** Quickshell/Hyprland runtime, graphical polkit authorization, real downloads and installation. These require an Arch desktop. No real upgrade was executed during development.

## Suggested runtime smoke test

1. Back up your live RusticQ directory and `user-settings.json`. Extract this package to a test folder.
2. Run `qs -p ./quickshell` from the directory containing it.
3. Open Settings, scroll navigation, visit OS / Hardware / Installed Apps / Storage and verify live values.
4. Open Arch Updater, press **Check updates**. Check the package list and warning messages. **Do not use Install** until ready for a real system-wide upgrade.
5. For a deliberate system upgrade, check the latest Arch news, back up data, click Install, then explicitly confirm. Monitor output until a verified completed/failed status.

All previous release notes remain in `changelog/`.
