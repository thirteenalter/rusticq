# RusticQ Alpha 4 RC1 — Floating Settings height fix

This is a **fix**, not a new release candidate.

- Retain the Settings floating window width at **940 logical pixels** to preserve the proportions in the desktop screenshot.
- Reduce initial height from **660 to 600 logical pixels**. Minimum from 760×540 to 760×500; users can still resize after opening.
- Keep the outer surface square and borderless so Hyprland controls corner rounding.
- Keep navigation and settings content in separate scrollable areas.
- On opening, the Hyprland helper matches the Settings window by its exact title and validated address; if it was tiled, it requests floating. When initial geometry does not match, it requests 940×600 and centers the window. It does not modify compositor configuration or unrelated windows.
- Do not modify user-settings.json, widgets, dock or any other UI.

## Testing

1. Start with `qs -p ./quickshell`, then open Settings.
2. Confirm it opens floating at a compact height; move it using the header and scroll the sidebar and a long page.
3. Resize manually (if the compositor permits) and reopen the window to verify its initial default is restored.
4. If it remains tiled, check `hyprctl -j clients` for the exact `RusticQ · Settings` title and inspect `qs log -f`.

Validated with offline static checks and mocked Hyprland dispatcher tests. Desktop runtime confirmation is still needed.
