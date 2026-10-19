# RusticQ Beta 1 — Live Displays and Workspace-Aware Confirmations

Base: `rusticq-beta1-launcher-hotfix-full.zip`. Both the full build and patch ZIP use a `quickshell/` root so patch files can be extracted directly over `~/dev/quickshell`.

## Confirmation

- Package install/uninstall confirmations now use a compact `FloatingWindow` rather than a fullscreen `PanelWindow` overlay.
- `scripts/rustiq-confirmation-float.py` finds Settings and the confirmation in `hyprctl -j clients`, matches exact titles and validated addresses, floats the dialog and moves it to Settings' workspace with `follow = false` on Hyprland Lua, with a legacy fallback. It does not change the active workspace or edit Hyprland config.
- Confirmation text, typed package-name authorization for uninstall and terminal-side sudo confirmation remain intact.

## Displays

- Resolution/refresh, scale, relative position and drag release request live updates immediately. Manual Apply is no longer needed.
- Runtime monitor application first uses the verified `hyprctl keyword monitor` approach (also used by HyprMon); if unsupported, tries the Lua monitor API. A readback is mandatory.
- Prior monitor layout is retained with owner-only file permissions in `~/.local/state/rusticq/display-pending.json`. A separate process rolls back after 15 seconds unless **Keep changes** is selected. **Revert now** and CLI `python3 scripts/rustiq-display.py revert` are also provided.
- Display changes affect only the running Hyprland session. Existing Omarchy monitor startup files remain untouched; export is an explicit step.

## Validation and limitations

- Offline unit regressions cover action dispatch, fallback, monitor validation, rollback ownership, and workspace targeting; no live Hyprland compositor or physical monitor was available in this build environment.
- Some unusual monitor profiles/Hyprland builds can reject legacy and Lua commands. The UI reports failure and attempts rollback. Reboot/TTY recovery may still be required if the compositor itself fails.

Reference: https://github.com/erans/hyprmon and https://wiki.hypr.land/configuring/core/monitors/.
