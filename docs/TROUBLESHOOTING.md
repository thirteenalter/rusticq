# RusticQ — Troubleshooting

## Startup fails or QML type unavailable

Run `qs -p /absolute/path/to/quickshell`, check `quickshell --version` and `qs log -f`, and paste the first QML error including its file and line. RC5 was developed for Quickshell 0.3.1; a new package release does not guarantee every API remains compatible.

## Icons are missing or appear as boxes

Check `pacman -Q ttf-material-symbols-variable`. `components/Icon.qml` falls back to **Material Symbols Rounded** when local `assets/google.ttf` does not exist. The user-local setup installs that fallback package. The optional Poppins fonts are *not* distributed; ordinary text falls back to a system sans font.

## Wi-Fi/Bluetooth controls do not work

Installed packages are not sufficient. Check `systemctl status NetworkManager`, `systemctl status bluetooth` and confirm the relevant adapters are detected. RusticQ does not enable these services on your behalf. A USB-tethered Ethernet interface is valid even when no Wi-Fi interface is found.

## An optional dependency install says “terminal opened” but nothing changed

“Terminal opened” only means the launcher request was queued. Read the terminal's output and confirm `INSTALL` a second time. Installation can fail due to unavailable packages, sudo permissions, Omarchy update guards or lack of network access. Click Refresh in Settings → Integration after completion.

## I installed via `install.sh` but Omarchy is still active

Expected: normal setup only creates `~/.local/share/rusticq/source` and a `rusticq` launcher. It never replaces the active shell. Start RusticQ manually and read Settings → Integration if you want optional permanent replacement.

## Restore Omarchy from TTY

If **permanent** Omarchy integration was enabled and startup no longer works, log in to another TTY and run:

```bash
python3 ~/.local/share/rusticq/shell/scripts/rustiq-desktop-integration.py revert --confirm 'RESTORE OMARCHY'
```

The CLI depends on the managed integration files remaining in place. If those files were manually removed, inspect `~/.local/state/rusticq/integration/backup/` and use the project's integration recovery notes instead of guessing which Lua lines to delete.

## Restore a user-local source update

Stop running RusticQ, inspect `~/.local/state/rusticq/setup-backups/`, and move the correct prior `source-...` directory to `~/.local/share/rusticq/source` after backing up the current install. This does not change Omarchy or its backup.

## Live display change / screen goes black

Changing a display from Settings applies at once but is provisional. Wait 15 seconds; the independent display rollback guard will attempt to restore the prior monitor layout if you do not press **Keep changes**. If Hyprland is still reachable in a terminal, use `python3 scripts/rustiq-display.py revert` in the RusticQ project to restore the pending snapshot immediately. `hyprctl -j monitors` lets you inspect the active outputs. If this also fails, return to a TTY to restore your own persisted monitor configuration. RusticQ does not overwrite your Omarchy monitor files during live changes.
