# RusticQ permanent integration: progress and file locations

**Installing the shell and activating it are different events.** The installer
stages the replacement for the **next login**. A progress value of 100% means
its files and manifest exist on disk; it does **not** assert that the current
Hyprland session is running the newly installed shell. The current-session
activation status remains unverified until the user logs out and logs in again.

Settings → Integration now shows a phase and a percentage for completed
installation steps. The backend records checkpoints atomically at
`~/.local/state/rusticq/integration/permanent-install-progress.json`. It
supports existing installations without that checkpoint by checking the
actual manifest, managed Hyprland startup hook, launcher, and installed shell.
If an expected file is missing, the status becomes `incomplete` rather than
falsely reporting 100%. On an interrupted process it reports `interrupted`
after the heartbeat becomes stale; it never guesses a time-based percentage.

## Files and directories

| Path | Operation |
| --- | --- |
| `~/.config/hypr/hyprland.lua` | Add a managed startup hook |
| `~/.config/hypr/bindings.lua` | Repoint **only existing RusticQ-managed** shortcuts, if necessary |
| `~/.local/state/rusticq/integration/autostart.lua` | Write private startup override |
| `~/.local/state/rusticq/integration/start-rusticq.sh` | Create launcher script |
| `~/.local/state/rusticq/integration/manifest.json` | Write restore metadata |
| `~/.local/share/rusticq/shell/` | Copy the RusticQ shell source |
| `~/.local/state/rusticq/integration/backup/` | Preserve snapshots of defaults and user configuration |
| `/usr/share/omarchy/default/hypr/autostart.lua` | **Read-only**, never changed |

These are the same absolute paths reported by the GUI, adjusted to the
user's XDG paths. Backups are preserved across enable and revert. Revert
restores only managed startup configuration, does not force a wholesale
replacement of user dotfiles, and archives the installed shell.

## Verify without writing

```bash
python3 scripts/rustiq-desktop-integration.py status
python3 scripts/rustiq-desktop-integration.py integration-progress
python3 scripts/rustiq-desktop-integration.py verify-backup
```

`integration-progress` reports JSON with `state`, `percent`, `phase`,
`next_login`, `checks`, and `changes` (each item includes path, action and
purpose). The progress endpoint is read-only. The report is not a substitute
for a compositor/runtime test of the newly installed shell.
