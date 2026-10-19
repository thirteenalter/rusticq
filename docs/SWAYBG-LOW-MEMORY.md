# RusticQ Beta 1 — swaybg Low Memory + measurable idle target

This update adds **swaybg** to Settings → Appearance → Wallpaper. It makes
`swaybg` the default choice **for new configurations** only. Existing saved
backend preferences remain unchanged. swaybg supports fill, fit, stretch,
center and tile, and output `*` applies to all monitors. It is **static** (no
animations) and is not a guarantee of a particular RAM reduction.

## Dependencies and changing backend

Install optional `swaybg` from Settings → Integration (`extra/swaybg` on Arch)
or using a trusted package manager. The wallpaper page supports a local
image from the current home directory and the five scale modes.

- **Apply wallpaper** starts a single managed swaybg process, reusing it if
  its image/output/mode already match. Its tracked PID and Linux process
  start time protect against accidentally signaling a reused PID.
- A conflicting hyprpaper/awww/swww daemon on the **same Wayland session**
  causes an error unless **Replace other wallpaper process on Apply** is
  explicitly selected. Replacement occurs only *after* swaybg starts.
- **Restore swaybg wallpaper when RusticQ starts** is opt-in; it is executed
  once per shell, not once per monitor. If Omarchy restarts a wallpaper daemon
  on login, separately opt into **Allow replacement ... at next login**; no
  packaged Omarchy configuration is edited.
- **Inspect** shows running wallpaper processes and managed swaybg PID.
  This command doesn't kill or launch a wallpaper daemon.
- Other wallpaper providers remain selectable. Switching to one retires
  RusticQ's owned swaybg only if the other provider reports success.

**Limitations:** If the compositor or another user service restarts a wallpaper
process after it is replaced, two wallpaper clients may appear again. RusticQ
cannot safely rewrite every external service's startup configuration. If a
process seems to be duplicated, Inspect first and review Omarchy's wallpaper
startup configuration. Do not indiscriminately `pkill` unrelated apps.

## Low Memory Shell Mode

Settings → Modules → Memory optimization offers an optional **Low Memory
Shell Mode**. It unloads the hidden AI panel window (which otherwise remains
resident to preserve in-flight requests). Closing the AI window with this
option enabled may interrupt responses or unsent drafts. Your existing
AI conversation singleton remains available. Default is **off** to preserve
existing UX.

## Memory benchmark on the user's hardware

`free -h` on the supplied sample reported 2.1 GiB used, 5.0 GiB available,
0 swap usage and 7.0 GiB physical RAM. `quickshell` showed ~465 MiB RSS,
`mariadbd` ~196 MiB RSS, `Hyprland` ~183 MiB, `ghostty` ~151 MiB, and
`xdm-app` ~105 MiB. RSS values **cannot safely be summed** to estimate unique
memory used (some pages are shared), and swaybg's actual effect requires a
before/after measurement on that Wayland session.

Measure with the same monitor arrangement, same running apps and 1–2 minutes
of settling after changing the wallpaper:

```sh
python3 scripts/rusticq-idle-memory.py --save-baseline
# Choose swaybg in Settings, Apply, then wait a minute.
python3 scripts/rusticq-idle-memory.py
free -h
```

Settings → Appearance → Wallpaper provides **Set baseline** and **Measure RAM**
to do this directly without a terminal. The report displays a `free`-style
system-used estimate, available RAM, per-process RSS/PSS where accessible,
change from baseline, and whether the measured value is below **2048 MiB**.
This is a single current-session snapshot, **not proof of truly idle usage**.
`MemTotal - MemAvailable` (working-set estimate) is reported separately.

The below-2 GiB goal is a performance **target, not a guarantee**. In
particular, moving to swaybg will not necessarily reduce RAM if no other
wallpaper daemon was running. On this user's system, Quickshell itself and
optional non-desktop applications are larger opportunities; never stop
MariaDB, PostgreSQL, downloads or another service automatically. Review and
stop only ones you know are unused.

## Offline validation

```sh
python3 tools/test_swaybg_low_memory.py
python3 tools/verify-static.py
```

A real swaybg/Quickshell/Hyprland session is required to validate GPU memory,
wallpaper output mapping, daemon startup, and achieved idle RAM.
