# Installation, upgrades, rollback

## Supported setup

- Arch Linux (including compatible Omarchy Quattro), Hyprland, and a Wayland login.
- Quickshell **0.3.1** is the Beta 1 development target. The Arch `quickshell` package may be newer; validate shell behavior before installing permanently.
- A network connection and sudo approval if dependencies need installing from pacman repos.
- `bash` and standard utilities; `python3` is bootstrapped when necessary on Arch.

## Manual test (no installation)

```bash
cd ~/dev/quickshell
qs -p .
```

This does not change compositor startup. You can also run `python3 scripts/rusticq-dependencies.py status` to list missing tools.

## Local user setup

```bash
cd ~/dev/quickshell
bash scripts/install.sh --dry-run
bash scripts/install.sh
~/.local/bin/rusticq
```

The installer:

1. Verifies the source contains `shell.qml` and the dependency manifest.
2. Checks for missing **core** Arch packages: `quickshell`, `hyprland`, `python`, `ttf-material-symbols-variable`.
3. Installs only missing packages, invoking interactive pacman/sudo. On a detected Omarchy system, it runs `omarchy update` first. It never uses `--noconfirm` or an AUR helper.
4. Copies the project to `~/.local/share/rusticq/source` and generates `~/.local/bin/rusticq`.
5. Backs up a previous RusticQ *source install* to `~/.local/state/rusticq/setup-backups/` rather than wiping it.

The setup does not edit `~/.config/hypr`, automatically enable services, or install RusticQ permanently. If `~/.local/bin` is not on PATH, run it by absolute path.

To install only the source without package management:

```bash
bash scripts/install.sh --skip-deps
```

To test the install plan on a non-Arch machine without side effects, use `--dry-run`.

## Optional dependencies in Settings

Use **Settings → Integration → Required & optional dependencies**. Click a missing optional item and enter `INSTALL` to install from the GUI; for an installed optional item type `REMOVE <id>` to remove it. A graphical Polkit agent authenticates the privileged pacman operation, and the result appears directly in Settings. Core dependencies cannot be removed here. Omarchy's own guarded package hooks remain enforced. Only packages in `config/dependencies.json` are accepted; arbitrary commands are not supported.

NetworkManager, BlueZ and PipeWire must have their services configured appropriately by the user or distribution. Packages are not proof a service is working.

## Permanent Omarchy Quattro integration (optional and separate)

Once RusticQ is running, open **Settings → Integration → Make RusticQ permanent**. On a verified Omarchy Quattro layout, the existing helper takes a backup before it changes your user Hyprland startup. It requires typing `ENABLE RUSTICQ`; restoring requires `RESTORE OMARCHY`.

This feature is **not** included in `scripts/install.sh` and does not uninstall Omarchy packages. If configuration signatures differ, it refuses activation. Test in a second user account or keep a TTY login available.

TTY recovery command after a permanent install (if the managed helper is still installed):

```bash
python3 ~/.local/share/rusticq/shell/scripts/rustiq-desktop-integration.py revert --confirm 'RESTORE OMARCHY'
```

## Full build vs patch

- **Full ZIP** contains the entire `quickshell/` source directory.
- **Patch ZIP** contains only new/changed paths under `quickshell/` and applies over the *matching Beta 1* source; it is not independently runnable.
- No scripts run automatically when a ZIP is extracted.

To overlay a patch on the development folder:

```bash
unzip -o rusticq-beta1-patch.zip -d ~/dev
cd ~/dev/quickshell && qs -p .
```

To update an already-installed `~/.local/share/rusticq/source` after changing the development folder, run `bash scripts/install.sh --skip-deps` again from the updated folder. This does not mutate the separate *permanent integration* copy under `~/.local/share/rusticq/shell`.

## Install via curl (GitHub main)

After publishing the Beta 1 `scripts/install.sh` to `thirteenalter/rusticq` on `main`:

```bash
curl -fsSL https://raw.githubusercontent.com/thirteenalter/rusticq/refs/heads/main/scripts/install.sh | bash
```

A piped installer cannot access the local `shell.qml`, so it downloads `https://codeload.github.com/thirteenalter/rusticq/zip/refs/heads/main` and checks archive size/path/symlinks before running the extracted project's local setup. The remote installer runs user-local setup and prompts before installing core pacman packages. It never enables permanent Omarchy integration.

For review before execution:

```bash
curl -fsSLo install-rusticq.sh https://raw.githubusercontent.com/thirteenalter/rusticq/refs/heads/main/scripts/install.sh
less install-rusticq.sh
bash install-rusticq.sh
```

This is a mutable branch and is **not pinned or checksum-authenticated** unless you independently provide `RUSTICQ_ARCHIVE_SHA256`. For reproducible signed-off releases, use `scripts/bootstrap.sh --url HTTPS_FULL_ZIP --sha256 RELEASE_SHA256`; it always verifies a published digest. Until this Beta 1 change is merged to GitHub main, the curl URL serves the older script.

## Roll back a user-local source update

Stop RusticQ, identify the appropriate folder under `~/.local/state/rusticq/setup-backups`, and manually move it back to `~/.local/share/rusticq/source`. This is **different from reverting permanent Omarchy integration**. Never delete the integration backup to “clean up” a regular source update.

## Full pre-install Omarchy backup and safe revert

When a compatible Omarchy Quattro session is detected, **Settings → Integration** saves a private snapshot of the installed Omarchy default Hyprland Lua files and the existing user `~/.config/hypr`, `~/.config/omarchy`, and `~/.config/quickshell` trees. The tree backup preserves symlinks without following them, has a bounded size, records SHA-256 per entry, and is never silently replaced on subsequent activation. Copies live in `~/.local/state/rusticq/integration/backup/`. Press **Verify backup** to check integrity.

`ENABLE RUSTICQ` requires a verified complete snapshot before modifying startup. `RESTORE OMARCHY` verifies existing original snapshots, archives current managed files in `revert-history/`, then removes RusticQ's managed startup integration. It does **not** blindly restore every folder from the snapshot: unrelated changes made after activation are preserved. For an older already-active install without the new full-tree snapshot, legacy backups remain revertible and are identified as incomplete rather than manufactured from modified files. Files in `/usr/share/omarchy` remain read-only.

**Protected package policy:** deleting `pacman`, `glibc`, `systemd`, `hyprland`, `quickshell`, or kernel package entries is intentionally blocked by RusticQ's GUI to protect desktop recovery. This restriction does not prevent manual system administration through the distribution's supported package tools.
