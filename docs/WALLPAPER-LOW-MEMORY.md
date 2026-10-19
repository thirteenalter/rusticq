# RusticQ Low Memory wallpaper (swaybg)

The existing RusticQ wallpaper interface now offers **swaybg** as the default
for new configurations. It uses static images, no animated transitions, and a
single managed process for all monitors (`swaybg -o '*' -i IMAGE -m fill`).
The selected backend, image path and restore-on-start checkbox are stored via
`SettingsStore`, without modifying Omarchy's distribution defaults.

## Activate from GUI

1. In **Settings → Integration → Dependencies**, install the optional
   **Swaybg — Low Memory Wallpaper** (`swaybg`) package if not present.
2. Open **Settings → Appearance → Wallpaper**, choose an image from your home
   directory, select **swaybg**, and click **Apply wallpaper**.
3. If another wallpaper backend is already running, RusticQ reports its name
   instead of killing it. Check **Replace other wallpaper process** for that
   *single* Apply operation only if you intend to replace that process.
4. Enable **Restore swaybg wallpaper when RusticQ starts** only if you want
   this wallpaper re-applied at your next login/Quickshell start. It defaults
   to off, to avoid unexpectedly competing with Omarchy's startup services.

If Apply previously stayed at “Applying wallpaper…” without starting swaybg,
the Appearance page had an unqualified QML reference to
`wallpaperReplaceConflicts`. The reference is now scoped to its wallpaper
section. The replacement checkbox resets after each Apply, and Apply ignores
clicks while the helper is running. Run `python3 -B tools/test_wallpaper_ui.py`
for an offscreen interaction regression with a fake backend and temporary settings.

The helper does **not** install packages, edit `~/.config/hypr`, or disable
Omarchy startup hooks. If Omarchy starts another wallpaper service on every
login, disable *that service's* autostart separately before enabling permanent
swaybg restore. A compositor or systemd-managed service may respawn after
termination; this helper never claims to modify the service manager.

The managed `swaybg` PID, Linux process-start timestamp, image and scaling mode
are stored under `$XDG_RUNTIME_DIR/rusticq-wallpaper/managed.json` (or the
user's XDG state directory if no runtime dir is available). Each repeated
Apply/Quickshell reload reuses an identical running process rather than
starting duplicates. Old managed swaybg is shut down only after the replacement
starts, and no arbitrary PID is killed without verifying owner, process name
and start time. External wallpaper applications only receive SIGTERM if you
explicitly check the replacement option in Settings. No `pkill -f` or shell
interpolation is used. External processes are matched to the current
`WAYLAND_DISPLAY` before RusticQ offers to replace them. Old swww/awww/hyprpaper modes remain available.

## RAM target: under 2 GiB at idle

**Target, not a guarantee.** Swaybg only saves resources related to wallpaper.
Desktop-wide RAM also includes the compositor, graphics buffers, portals,
services, open apps, disk cache and other Omarchy processes.

In Settings → Appearance, use **Set baseline** before switching and **Measure RAM** afterwards, or run:

```sh
python3 scripts/rusticq-idle-memory.py --save-baseline
# Apply swaybg then wait for the desktop to settle.
python3 scripts/rusticq-idle-memory.py
```

Read `system_used_mib`, `target_mib`, `under_target`, the separate
`system_working_set_mib` estimate, and per-process RSS/PSS (when permitted).
`system_used_mib` approximates the **free(1) used** column. `system_working_set_mib`
is **MemTotal - MemAvailable**. Neither is the sum of process RSS values.
Perform measurements on **your own Hyprland machine** after login, close
browsers, terminals and other user applications, and compare idle samples
several times. The indicator reflects a point-in-time reading, not proof of
quiescent idle. If memory exceeds the target, inspect the process breakdown,
including systemd services, before disabling useful system components.

For an apples-to-apples comparison, measure before/after the wallpaper backend
change on the same monitor configuration and image, and restart the session if
Omarchy autostart processes keep reappearing. The helper does not claim
benchmarks from the developer build environment reflect your machine.

## Dependencies & compatibility

- `swaybg` is available through official Arch repositories and is optional.
- Supported modes: `fill` (default), `fit`, `stretch`, `center`, `tile`.
- `swaybg` supports output selection, with `*` targeting all active outputs;
  RusticQ's Settings currently applies one image to all monitors.
- Static wallpapers do not animate. Animated wallpaper backends are still
  available but may have different resource usage.
- Restoration on startup is **opt in**. This update does not alter the
  original Omarchy or Hyprland default wallpaper autostart files.

Back up the existing user settings before changing visual preferences. Release
ZIPs intentionally omit `user-settings.json` so extraction does not reset
an existing user's settings. The full ZIP also excludes local font binaries.

### Authoritative Beta 1 basecode

This build ports swaybg and optional low-memory UI directly into the supplied **full Beta 1 quickshell.zip**. It does not replace the workspace-aware widget/notes methods or Native Lock Screen, Wi-Fi/QR, notifications, Omarchy backups, and keyboard shortcut components with the earlier minimal source. Existing wallpaperBackend values are retained when saved preferences load; only new configurations default to swaybg. Omarchy wallpaper processes are not killed without user permission.
