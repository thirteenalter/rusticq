# Beta 1 · Power Menu Alignment & Native Omarchy ASCII Screensaver

Base: `rusticq-beta1-ventoy-search-power-border-full.zip`.

- Kept the existing centered **PanelWindow / Wayland Overlay** power menu with Escape and click-outside dismissal.
- Header and all six action rows now share the exact same horizontal grid: left padding 12, fixed 40px icon column, 12px gap, flexible title/subtitle, fixed 24px right-aligned shortcut column. Outer card keeps `Theme.sectionRadius` and its original one-pixel `Theme.borderaccent` border.
- Removed the previous misleading "Lock and dim screen" hint on Screensaver. This action now calls the **existing Omarchy ASCII screensaver** with `omarchy-launch-screensaver force` (not `hyprlock` and not DPMS off).
- A detached Python helper waits 0.9 seconds after the overlay confirms success, allowing RusticQ to close its Power Menu layer before the Omarchy screensaver terminal is created. This avoids the known Omarchy race when a layer-shell power panel remains open.
- If `omarchy-launch-screensaver` is unavailable, the menu reports an error and does not fake a screensaver.
- Lock, Suspend, Logout, Reboot and Shutdown retain their previous actions and confirmations.

## Install

Extract the **patch ZIP** with `-d ~/dev` (the archive contains the `quickshell/` directory). No installer or Omarchy config changes. Restart from `~/dev/quickshell` using `qs -p .`.

## Verification

Run `python3 tools/test_beta1_power_alignment_omarchy.py`. This covers UI structure, native command, delayed start and unchanged power commands. Visual geometry and actual ASCII animation require a live Hyprland/Omarchy session.

Reference: Omarchy Quattro manual and native launcher documentation: https://github.com/omacom/omarchy/blob/quattro/manual/13-toggles-idle-screensaver.md
