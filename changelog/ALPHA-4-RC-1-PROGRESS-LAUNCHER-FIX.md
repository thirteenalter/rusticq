# RusticQ Alpha 4 RC1 — updater progress & launcher settings fix

This is a **correction to RC1**, not a new RC or release version.

## Arch Updater

- Pacman output is now captured from a pseudo-terminal (PTY). This preserves
  carriage-return progress updates that can disappear when stdout is a pipe.
- Status displays the **actual percentage of the current package/download**,
  not a speculative overall transaction percentage.
- Package/hook counters (`1/42` etc.) are shown when provided by pacman.
- No number is invented when pacman does not report one. The small rotating
  activity icon means "working", not "X% complete".
- Detailed output continues to be saved under
  `~/.local/state/rustiq/updater/pacman.log` (or `XDG_STATE_HOME`).
- The process remains detached from Settings; an explicit confirmation and
  PolicyKit agent are still required for a real `pacman -Syu`.

**Important:** The per-item progress bar may return to 0 or become unknown when
pacman starts another package. This is expected. It is **not** total upgrade
progress. The entire transaction is only marked complete after a successful
exit code. Review Arch announcements and `.pacnew` files before upgrading.

## Launcher settings

- New sidebar page: **Settings → App Launcher**.
- Live, persistent controls:
  - Window width: 440–1000 px (default 660)
  - Window height: 360–850 px (default 605)
  - Application icon size: 20–64 px (default 30)
  - Result row height: 50–92 px (default 56)
  - Favorite columns: 2–5 (default 3)
- The launcher remains one surface, centered on the selected monitor.
- The available screen bounds clamp the requested width/height; result rows
  cannot be smaller than the selected icon plus padding. Favorites collapse on
  very short launcher windows to preserve room for search results.
- The **Reset launcher dimensions** button restores defaults.
- Existing preferences are preserved; new keys are loaded with validation.

## Verification

Run from the unpacked `quickshell` directory:

```bash
python3 tools/verify-static.py
python3 tools/test_updater_launcher_fix.py
python3 tools/test_alpha4_rc1.py
qs -p .
```

No real pacman transaction was executed in the build environment. PTY handling
and output parsing were verified with synthetic pacman-like text. Test on your
Arch/Hyprland session before relying on the updater UI for system operations.
