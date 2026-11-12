# RusticQ Beta 3 — swaybg restore after reboot / login

## What the failure means

`swaybg` **does not read a desktop wallpaper configuration automatically**.
Launching `uwsm-app -- swaybg` without image, color, or mode flags creates a
process which cannot paint any output. Logs such as:

```
Could not find config for output eDP-1 (...)
Could not find config for output HDMI-A-1 (...)
```

indicate that **no matching appearance configuration was provided** for
either screen. The valid command is approximately:

```sh
uwsm-app -- swaybg -o '*' -i "$HOME/Pictures/your-wallpaper.jpg" -m fill
```

Replace the example image path with a real JPG/PNG/WebP/BMP. The `*` output
covers both current outputs and newly attached outputs. This syntax follows
swaybg's `--output`, `--image`, and `--mode` command-line interface.

## What the patch changes

- Before this patch, `SettingsStore.wallpaperAutoRestore` defaulted to false,
  and **Apply wallpaper** never switched it on. A wallpaper could display
  immediately but vanish after reboot. The old startup timer also depended
  on the active source tree's `user-settings.json`.
- After a successful **Settings → Appearance → Wallpaper → swaybg → Apply**, the
  helper saves a private cross-installation profile at
  `~/.config/rusticq/wallpaper-restore.json`. This contains only the wallpaper
  path, scaling mode, wildcard output `*`, and an explicit replacement policy.
  It contains no API keys. File permissions are `0600`; the directory is `0700`.
- At shell startup, RusticQ calls `rusticq-wallpaper.py --restore` once. The
  command reads that profile independent of whether the current Quickshell
  source is `~/dev/quickshell` or `~/.local/share/rusticq/shell`. Existing
  enabled preferences in `user-settings.json` are migrated automatically if
  no profile exists yet. A profile explicitly marked off is never re-enabled
  by stale settings from another shell copy.
- Wallpaper remains managed by one swaybg instance; repeated launches reuse
  an already correctly configured instance. An **exact bare swaybg process**
  on the same Wayland session (no `-i`/`-c` settings at all) may be stopped
  **only after** the configured replacement launches successfully. All other
  active wallpaper providers require explicit approval to replace.
- Settings has an explicit restore toggle. Disabling it persists across both
  DEV and permanently installed shell copies. Replace-on-login is an independent
  opt-in, never assumed because you replaced a process once.
- Omarchy distribution defaults, Hyprland configuration, autostart units, and
  settings backups are **not modified** by this patch.

## Installation and first run

1. Overlay the patch onto the **RusticQ Beta 3 Compositor Studio** release.
2. Launch a single updated RusticQ session (`qs -p .` from your dev folder,
   or reapply into the permanent shell through Integration).
3. Pick a **real local image**, select `swaybg`, and click **Apply wallpaper**.
4. Check it appears on `eDP-1` and `HDMI-A-1` and that **Restore after login**
   is enabled; then log out and log back in to verify startup restoration.

Read-only verification:

```sh
python3 scripts/rusticq-wallpaper.py --status
cat ~/.config/rusticq/wallpaper-restore.json
pgrep -af swaybg
```

Non-destructive manual restoration of the saved wallpaper profile:

```sh
python3 scripts/rusticq-wallpaper.py --restore
```

If an unrelated `hyprpaper`, `awww`, or other configured wallpaper service is
running, the helper **will not stop it without explicit permission**. Inspect
startup services first rather than using `pkill` or deleting Omarchy defaults:

```sh
rg -n 'uwsm-app.*swaybg|exec.*swaybg' ~/.config/hypr ~/.config/systemd/user ~/.config/autostart 2>/dev/null
systemctl --user list-units --all | grep -i swaybg
```

When a persistent service launches bare `swaybg`, remove or fix *that user
configuration* explicitly after reviewing it. The patch does **not** silently
edit unrelated user autostarts or systemd units.

## Limitations and regression coverage

- Wallpaper needs an existing image inside the current user's home directory.
- The helper uses native swaybg/wlr-layer-shell; actual Wayland drawing and
  login timing require tests on the user's desktop. No RAM benchmark or
  GPU/resource saving is claimed without a real measurement.
- New tests verify profile persistence/permissions, disabled restore,
  migration, invalid images, bare/unconfigured processes, non-bare conflicts,
  and QML dispatch. Existing low-memory tests remain unchanged.
