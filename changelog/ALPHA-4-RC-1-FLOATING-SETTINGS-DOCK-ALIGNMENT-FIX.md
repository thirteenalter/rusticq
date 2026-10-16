# RusticQ Alpha 4 RC1 — Floating Settings & Dock Alignment Fix

This is a **correction to RC1**, not a new release/version.

## Settings window

- The initial **FloatingWindow** size is **940 × 660 px** with a 760 × 540 minimum; `maximized` and `fullscreen` are explicitly disabled.
- Removed the header close button; close using Hyprland's window close shortcut (typically `SUPER+Q`), `Alt+F4`, or a window manager close action. Escape is not intercepted.
- Removed the **outer** QML rounded rectangle and border; Hyprland is responsible for clipping/decorating the *window* corners. Internal cards (sidebar, inputs, sections) retain RusticQ's design tokens.
- Drag the Settings title header to request a compositor-managed window move.
- Added `scripts/rustiq-settings-float.py`: after Settings opens, read `hyprctl -j clients`, match the exact `RusticQ · Settings` title and a validated address, then use the Lua dispatcher to set floating and center **only that specific window**. It does not rewrite any Hyprland configuration. On a non-Hyprland session, the helper is a no-op.

If the session's Hyprland version or window rules override the helper, an optional persistent **Lua** window rule can be added to your existing Hyprland configuration (check your local configuration's placement and syntax):

```lua
hl.window_rule({
    name = "rustiq-settings-floating",
    match = { initial_title = "^RusticQ · Settings$" },
    float = true,
    center = true,
})
```

The patch **does not install this rule automatically**.

## Dock

- Removed the estimated dock width formula that reserved space for virtual icon slots and led to excess padding on one side.
- Width now follows `contentRow.implicitWidth + 2 × 10px`, clamped to the screen's safe width. Left and right margins use the same value.
- Content row is centered when there is spare room and scrolls when the number of launched windows exceeds available width.
- Existing running-app integration, dock auto-hide and shortcuts are unchanged.

## Testing

Run `python3 tools/verify-static.py` and `python3 tools/test_settings_floating_dock_padding.py`.

Runtime checks on your own Hyprland session: open Settings, ensure it is floating/non-maximized, verify the outer corners are controlled by Hyprland, and drag the header; expand the dock with several running apps and compare left/right padding. This build environment **cannot confirm live Wayland behavior**.
