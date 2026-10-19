# Shell Updates V2 — GitHub release → DEV or PERMANENT

This extends the existing RusticQ Beta 1 integration; it does not replace the
Arch/Omarchy system updater. **Check GitHub is allowed even when permanent
integration has been restored to Omarchy** and the installed shell is absent.

## Settings → Integration → Shell Updates

- GitHub Releases metadata is fetched **once when Settings loads** and then
  at most once per hour while the page is visible; no persistent background
  daemon and no download without explicit approval.
- Select **DEV** to update `~/dev/quickshell`, whether or not RusticQ is
  permanently installed. This path remains usable after restoring Omarchy.
- Select **PERMANENT** to update `~/.local/share/rusticq/shell` when a valid
  permanent integration manifest exists. Use **Reapply Local** to install the
  current DEV source into PERMANENT after confirmation.
- **Rollback Shell** restores the most recent backup of the *selected target*.
  DEV backups are stored alongside DEV as `quickshell-before-update-*`;
  installed backups alongside the installed shell as `shell-before-update-*`.
  Each update creates its own complete, undoable backup.
- User settings are carried forward. DEV `.git` metadata is preserved; its
  worktree may differ from `HEAD` after a release replaces files, so run
  `git status` before using git to commit or pull additional changes.
- Downloads prefer a **full release ZIP with a published SHA-256** digest or
  checksum asset. If the release has no verified full ZIP, the official
  GitHub-generated **source ZIP** can be used. Its transport is HTTPS and its
  observed SHA-256 is recorded, **but it has no independent published
  checksum**; the Settings confirmation states this explicitly. Patch-only
  release assets and malformed/traversal ZIPs cannot be installed.
- No `curl | sh`, root commands, automatic session restarts, package upgrades,
  or writes to `/usr/share/omarchy/default`.

## Commands

```sh
cd ~/dev/quickshell
python3 scripts/rusticq-shell-updates.py check --tag beta-1
python3 scripts/rusticq-shell-updates.py update-shell --tag beta-1 --target dev --confirm 'UPDATE SHELL'
python3 scripts/rusticq-shell-updates.py rollback --target dev --confirm 'ROLLBACK SHELL'
# After enabling RusticQ permanently:
python3 scripts/rusticq-shell-updates.py reapply-local --target installed --confirm 'REAPPLY LOCAL'
python3 scripts/rusticq-shell-updates.py rollback --target installed --confirm 'ROLLBACK SHELL'
```

## Restore Omarchy → install RusticQ again

The permanent integration's prior backend rejected left-behind startup/shim
files. This release detects them and, **after verifying the original backups**,
archives recognizable stale `autostart.lua`, `start-rusticq.sh` and installed
shell trees to `~/.local/state/rusticq/integration/stale-install-history/`.
The previous copies are **never deleted** and are restored if the installation
transaction fails. Symlinks, unknown contents, an active manifest or active
managed startup hook are never overwritten silently.

Use Settings → Integration → **Make RusticQ permanent**, type the exact
`ENABLE RUSTICQ` confirmation, and click **Install RusticQ for next login**.
The page now exposes stale paths when they exist; install reports them as
`recovered_files`. You can diagnose without changes using:

```sh
python3 scripts/rustiq-desktop-integration.py status
python3 scripts/rustiq-desktop-integration.py verify-backup
python3 scripts/rustiq-desktop-integration.py enable --confirm 'ENABLE RUSTICQ'
```

The last command changes startup *after backup verification*; use it only when
intending to install. Successful installation configures the **next login**
and does not claim the current Wayland session was already replaced.

## Testing limitations

Tests simulate GitHub ZIP downloads and temporary home/config directories.
The authoring environment cannot reach the real GitHub API or start the user's
Hyprland/Quickshell session, so live asset availability and UI focus must be
verified on the device. A published checksum from the same repository
provides integrity, not an independent signature of its publisher.
