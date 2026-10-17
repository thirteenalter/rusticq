# Installation, upgrades, rollback

## Supported setup

- Arch Linux (including compatible Omarchy Quattro), Hyprland, and a Wayland login.
- Quickshell **0.3.1** is the RC5 development target. The Arch `quickshell` package may be newer; validate shell behavior before installing permanently.
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

Use **Settings → Integration → Required & optional dependencies**. Click a missing item, enter `INSTALL`, then choose **Open interactive installer**. The terminal asks for `INSTALL` again and displays the package before launching pacman. On Omarchy the updater runs first. Only packages in `config/dependencies.json` are accepted; arbitrary commands are not supported.

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
- **Patch ZIP** contains only new/changed paths under `quickshell/` and applies over the *matching RC5* source; it is not independently runnable.
- No scripts run automatically when a ZIP is extracted.

To overlay a patch on the development folder:

```bash
unzip -o rusticq-alpha4-rc5-setup-patch.zip -d ~/dev
cd ~/dev/quickshell && qs -p .
```

To update an already-installed `~/.local/share/rusticq/source` after changing the development folder, run `bash scripts/install.sh --skip-deps` again from the updated folder. This does not mutate the separate *permanent integration* copy under `~/.local/share/rusticq/shell`.

## Future HTTPS bootstrap

`bash scripts/bootstrap.sh --url FULL_ZIP_HTTPS --sha256 RELEASE_SHA256` accepts a verified release. The real URL and checksum must be published first. An example publishing flow is:

1. Upload the **full** ZIP and `scripts/bootstrap.sh` to an HTTPS release location.
2. Publish the ZIP's SHA-256 via a trustworthy release channel.
3. Download/review bootstrap with `curl -fsSLo bootstrap.sh '<ACTUAL_BOOTSTRAP_URL>'` and run with the verified ZIP URL + digest.

The bootstrap rejects non-HTTPS URLs, checksum mismatches, ZIP traversal, symlink entries and oversized ZIPs. No URL is hardcoded until hosting is configured. Do **not** copy a placeholder into a real shell expecting it to work.

## Roll back a user-local source update

Stop RusticQ, identify the appropriate folder under `~/.local/state/rusticq/setup-backups`, and manually move it back to `~/.local/share/rusticq/source`. This is **different from reverting permanent Omarchy integration**. Never delete the integration backup to “clean up” a regular source update.
