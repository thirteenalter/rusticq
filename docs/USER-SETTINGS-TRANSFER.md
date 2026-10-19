# Save / Load User Settings in Settings → Integration

RusticQ already uses `config/SettingsStore.qml` and `user-settings.json` as the
single source of truth for user customization. This feature extends the existing
`scripts/rusticq-config-guard.py` to export and import that configuration, **not**
create a duplicate preference store.

## In the UI

1. Open **Settings → Integration → User settings · Save / Load**.
2. Click **Save user settings**. A new JSON file is created under
   `~/Documents/RusticQ-Settings/rusticq-settings-<timestamp>-<random>.json`.
   Its location is shown, so you can copy it to another device.
3. For **Load**, choose a file via **Browse settings JSON** (requires zenity,
   kdialog or yad), or paste its path into the field. Use **Validate & preview
   import** to confirm the format and number of fields.
4. Type **IMPORT SETTINGS** to explicitly approve overwriting the active
   `user-settings.json`. This creates a separate timestamped recovery snapshot
   *before* any change and checks the file's SHA-256 again, rejecting it if the
   file changed after preview.
5. **Restart the active RusticQ/Quickshell instance** after a successful import.
   The running QML singleton has cached preferences; a file import does **not**
   hot-reload every setting. Avoid changing any settings before restarting,
   because that could save old in-memory values over the newly imported file.

### What's included?

Everything saved by the active `SettingsStore.save()` to `user-settings.json`:
appearance, fonts, bar placement/visibility, wallpaper preferences, module
visibility, desktop widget locations, per-workspace notes, dock, launcher,
layout, AI provider/model names, and other user settings. Imported local paths
(such as wallpaper files) only work on another device if those files exist.

### What's excluded?

Not included: API credentials stored in the system keyring, app usage history,
Omarchy system config/backups, Hyprland dotfiles, wallpaper image binaries,
plugins, installed applications, or the current source code. The exporter
also strips additional JSON keys with credential-like names such as `token`,
`password`, `secret`, `credential`, or `apiKey` (including nested keys) if
present in the source JSON.

**Treat the exported JSON as private**: widget notes, wallpaper paths, and
other local settings may reveal personal information. Never publish it as a
public GitHub release asset.

## CLI

All operations are unprivileged; they never call sudo, pkexec, pacman, or
change Hyprland's startup or Omarchy's defaults.

```bash
cd ~/dev/quickshell
python3 scripts/rusticq-config-guard.py export
python3 scripts/rusticq-config-guard.py inspect --path ~/Documents/RusticQ-Settings/my-config.json
# Copy sha256 from the inspect output, then explicitly approve:
python3 scripts/rusticq-config-guard.py import --path ~/Documents/RusticQ-Settings/my-config.json --sha256 <sha256_from_inspect> --confirm 'IMPORT SETTINGS'
```

The backend also accepts a plain legacy `user-settings.json` as an input.
Portable exports are JSON wrappers with format `rusticq-user-settings`, version
`1`, and a `settings` object. Unexpected future wrapper versions are rejected.
Files larger than 2 MB, malformed JSON, symlinked input/target, non-finite JSON
numbers, extreme nesting, and prototype keys are rejected. All paths are passed
as subprocess arguments, without shell interpolation. Output JSON files are
written with permission `0600`; a new output filename is always generated.

Recovery snapshots continue to use the existing config guard's storage:

`~/.local/state/rusticq/config-backups/settings/`

To restore a snapshot manually:

```bash
python3 scripts/rusticq-config-guard.py list --kind settings
python3 scripts/rusticq-config-guard.py restore --kind settings --id SNAPSHOT_ID --confirm RESTORE
```

## DEV versus permanent shell

`Quickshell.shellPath` binds to the currently running source tree. When running
`qs -p ~/dev/quickshell`, the source is the dev `user-settings.json`. When
running the permanent shell installed to `~/.local/share/rusticq/shell`, the
source is the settings file there. Save and Load change only that currently
running copy. Use shell updates' **Reapply Local** separately to copy code; it
is *not* required for moving a settings export between instances.

## Verification

`python3 tools/test_portable_user_settings.py` and
`python3 tools/test_phase1_doctor_guard.py` exercise JSON compatibility,
export, import, SHA-256 protection, automatic backups, and error paths using
only temporary test files. Live Qt/QML UI needs validation on Hyprland.
