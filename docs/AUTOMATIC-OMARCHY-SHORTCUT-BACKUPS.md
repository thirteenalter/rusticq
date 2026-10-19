# Automatic Omarchy backups for RusticQ shortcuts

Every **Apply override**, **Apply new key**, **Restore selected**, and **Revert selected** now executes a fail-closed backup **before** touching `~/.config/hypr/bindings.lua`. The backup works for users with regular Hyprland too; full Omarchy defaults are archived when present.

## What is actually backed up?

1. **Once, immutable:** the complete installed `OMARCHY_PATH/default` tree (`/usr/share/omarchy/default` by default)—not only its `hypr` folder. The archive preserves file contents, original mode metadata and nested symbolic links, and records SHA-256 hashes. Existing original permanent-integration snapshots (if present) remain untouched.
2. **Every shortcut mutation:** `~/.config/hypr`, `~/.config/omarchy`, `~/.config/quickshell`, Waybar, Mako, SwayNC, SwayOSD, Walker, Fuzzel, Rofi, Wofi, Wlogout, terminal/desktop configs, Starship, Fastfetch, Btop, Neovim, UWSM, plus `~/.zshrc`, `~/.bashrc`, `~/.profile` and other listed shell dotfiles. The exact allowlist is `SHORTCUT_CONFIG_DIRS`, `SHORTCUT_CONFIG_FILES` and `SHORTCUT_HOME_DOTFILES` in `scripts/rustiq-desktop-integration.py`.

This is a **desktop/Omarchy dotfiles backup**, not an unconditional backup of the entire home directory or all of `~/.config`. Browser profiles, password databases and unrelated private application data are not scanned.

## Where?

- Installed Omarchy defaults: `~/.local/state/rusticq/integration/backup/omarchy-default-complete/`
- User history: `~/.local/state/rusticq/integration/backup/shortcut-history/<timestamp>/`
- Previous original pre-install backups: `~/.local/state/rusticq/integration/backup/` (unchanged)

Both archives have `manifest.json` and a SHA-256 for each file. Directories are private (`0700`), archived regular files have permission `0600`. Archive entries include original permission modes for manual recovery. Snapshots are **never included in release ZIPs**, never sent over the network, and are **not automatically restored over user edits**.

## Verify and restore

Settings → Shortcuts now has three explicit steps:

1. **Create backup now** immediately writes and SHA-256-verifies the complete installed Omarchy defaults (if present) plus a timestamped snapshot of Hyprland and related dotfiles. It does **not** change shortcuts.
2. **Verify backup** can be clicked even when the status is **0 snapshots**. In that case it reports exactly why verification cannot pass. With archives present it verifies the default snapshot and **all** historical user snapshots against their checksums.
3. **Apply override** / **Restore selected** / **Apply new key** / **Revert selected** opens a dedicated floating confirmation on the Settings workspace. It shows the affected binding, explains both backup scopes, and explicitly requires consent for recovery-key overrides (`SUPER + ESCAPE` / `SUPER + BACKSPACE`). Clicking **Back up & continue** writes and verifies backups **before** modifying Lua. A failure is displayed in Settings and aborts the change.

The snapshot count is the number of *verified-created user history snapshot directories*; **0 snapshots means no user history has been created**, not that a hidden backup definitely exists. The status does not claim that backups are verified until you run **Verify backup**.

You can also use CLI:


```sh
python3 scripts/rustiq-desktop-integration.py create-shortcut-backup
python3 scripts/rustiq-desktop-integration.py list-shortcut-backups
python3 scripts/rustiq-desktop-integration.py verify-shortcut-backups
python3 scripts/rustiq-desktop-integration.py shortcut-revert --action power
```

The last command restores an individual managed binding, **not** your entire dotfiles tree. For a manual file recovery: verify first, choose the appropriate timestamp, inspect its `manifest.json`, compare the saved file with the current file, and copy **only the needed file** back after making another backup of your current configuration. Restoring every dotfile blindly would discard unrelated newer edits.

If this feature is installed *after* shortcuts were already overridden, new history snapshots begin with the **current** configuration; they cannot reconstruct older pre-RusticQ user edits. If original pre-install backups already exist, they stay available separately. Complete upstream Omarchy defaults can still be archived because RusticQ never edits `/usr/share/omarchy/default`.

## Safeguards

- No shortcut mutation unless newly created user/default backups have been written and verified. The **Verify backup** command checks every historical snapshot on demand.
- Existing default archive checked on every later change; checksum corruption blocks further changes.
- Maximum single file: 64 MB; total complete defaults: 512 MB; user dotfiles per change: 256 MB; maximum entries: 18,000. Failure reports an error and leaves live bindings unchanged.
- Top-level symlinked config directories are rejected to prevent a falsely complete backup of an external directory. Nested symlinks are saved as symlinks, without following them.
- No direct changes to original Omarchy files, startup hooks, or system packages.
- Existing backup directories and snapshot histories are never silently overwritten or deleted.

## If the confirmation window or Verify does not open

Launch a fresh `qs -p .` from the updated `~/dev/quickshell` directory. Check `qs` logs for `ShortcutBackupConfirmationWindow` errors. You can independently verify the backend without altering shortcuts by running `python3 scripts/rustiq-desktop-integration.py create-shortcut-backup`, followed by `python3 scripts/rustiq-desktop-integration.py verify-shortcut-backups`. If either command returns `ok:false`, its `message` identifies the missing source, ownership, symlink, size, or checksum problem. Do not bypass the error with a direct `o.rebind` edit: that would defeat the backup guarantee.
