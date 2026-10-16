# RusticQ Alpha 4 RC1 — Omarchy Updater & Running Apps Fix

This is a **correction to Alpha 4 RC1**, not a new release.

## Omarchy guard recovery

An Omarchy pre-transaction hook deliberately rejects a direct `pacman -Syu`. Omarchy requires its `omarchy update` workflow so package updates, snapshots, migrations, and post-update steps stay consistent. RusticQ now detects an installed Omarchy (`omarchy` executable or the Omarchy ALPM guard) and **does not launch pacman** for it.

The Settings → Arch Updater button changes to **Open Omarchy update**. After a confirmation, RusticQ launches `omarchy update` in an interactive terminal (`xdg-terminal-exec`, Foot, Kitty, etc.). Answer all authentication and update prompts there. No automatic retry, no `OMARCHY_ALLOW_DIRECT_PACMAN=1`, and no hidden bypass. A previous failed transaction with an Omarchy guard message is also recognized from the saved RusticQ updater log, with recovery guidance.

**Output distinction:** On ordinary Arch, RusticQ continues to capture per-item pacman progress from a PTY. On Omarchy, the terminal runs the official interactive update; RusticQ may display the Omarchy-owned `/tmp/omarchy-update.log` transcript when it has a recent timestamp. Do not interpret closing the terminal or a successful launch as a completed update. Verify the final outcome in the Omarchy terminal. If no compatible terminal is found, run `omarchy update` yourself.

## Dock running apps

Previously the dock took snapshots from `Hyprland.toplevels.values` and expected `appId` in the wrong place, which could leave the dock empty. It now uses Quickshell 0.3.1's **live `Hyprland.toplevels` ObjectModel** directly, and reads `Toplevel.appId`/`activated`/`activate()` from its delegate. The list updates when windows open and close; clicking an icon requests activation. Actual desktop icon names are looked up via `DesktopEntries.heuristicLookup()`.

This is **not** a process list: applications without a graphical toplevel do not appear. Multiple open windows of one application can each get an entry. Hover is used to expand the dock when auto-hide is on.

To test: Settings → Dock → Enable dock → Show running apps. Start two GUI applications, check their icons appear, and click each to focus. To diagnose zero entries, run `hyprctl -j clients` and confirm the compositor reports windows, then inspect `qs log -f`.

## Validation and limitations

- Source static checker: QML structure/imports examined (not a complete Qt QML compiler).
- Offline tests: past Omarchy guard log, terminal selection, direct-pacman bypass prevention, PTY progress fixture, and running-app source behavior.
- No pacman transaction was performed. Live graphical terminal, notification policies, and Hyprland toplevel activation still require runtime testing on your system.

Installation: extract the full archive into a separate directory or overlay the patch onto your RusticQ `quickshell/` folder. Back up before replacing files. **Patch ZIP contains no `user-settings.json`.**
