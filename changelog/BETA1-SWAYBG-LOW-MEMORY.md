# Beta 1 — swaybg Low Memory wallpaper backend

Based on the user-provided `quickshell.zip` source snapshot.

## Updated source

- `scripts/rusticq-wallpaper.py`: swaybg process lifecycle, one private PID and Linux starttime, reuse on repeated apply, atomic state, controlled explicit switching from competing wallpaper providers, support for multi-output image fill, and maintain existing animated backends.
- `scripts/rusticq-idle-memory.py`: on-demand *system-wide* free-style RAM snapshot, baseline comparison, and per-process RSS/PSS. Target is below 2048 MiB idle, **not guaranteed** without measurements on the actual desktop.
- `modules/settings/pages/SettingsAppearancePage.qml`: backend selector, preview size cap, safe switch checkbox, opt-in restore, memory report, scaling mode and opt-in login-time replacement.
- `modules/settings/SettingsWindow.qml`: wallpaper feature search hints.
- `config/SettingsStore.qml`: persist backend, scaling, Low Memory Shell Mode and optional restore settings; migrate older backend values.
- `shell.qml`: single startup attempt once per shell instance and optional hidden-AI unloading, never per monitor.
- `config/dependencies.json`: optional `wallpaper-swaybg` official Arch swaybg package installable via Settings → Integration.
- `scripts/install.sh`: preserve installed user preferences; create clean settings file only on fresh install.
- `tools/test_swaybg_low_memory.py` and dynamic dependency count test: isolated regressions without requiring a running Wayland session.
- `docs/WALLPAPER-LOW-MEMORY.md`, `docs/DEPENDENCIES.md`, and README updated.

## Scope and limitations

This update does not disable an Omarchy-provided wallpaper service. Switching away from a separate running wallpaper process requires explicit permission; autostart restoration is also opt-in. It does not automatically install packages or mutate Hyprland/Omarchy configuration. The current build environment cannot execute the target Wayland/swaybg process or measure the end-user desktop's actual idle RAM.

The release ZIPs exclude `.git`, locally bundled font binaries and machine-local `user-settings.json`. Full extraction onto an existing source tree therefore does not overwrite those local files. Because the baseline was the **user-uploaded zip** (not a verified later repository commit), test or merge against newer personal sources before replacing them wholesale.
