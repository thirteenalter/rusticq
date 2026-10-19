# RusticQ Beta 1 — Power Menu uses RusticQ Lock Screen

- **Power Menu → Lock** now explicitly uses RusticQ's Hyprlock/PAM theme, never a fallback locker.
- The theme is rendered and checked before closing the Power Menu. If Hyprlock is absent or rendering fails, an error stays visible in the Power Menu.
- After successful confirmation, Power Menu releases its Wayland overlay and keyboard focus, then the theme-backed lock process starts after 850 ms. Authentication remains owned by Hyprlock/PAM.
- Shortcut / IPC `lock`, Settings → Appearance → Lock now, native Omarchy ASCII Screensaver, and other power options are unchanged.
- No changes to Omarchy's lock configuration, PAM, service setup, or keyboard shortcuts.

## Quick check

Run `python3 scripts/rusticq-lockscreen.py status` to verify Hyprlock availability and theme preferences, then open Power Menu and choose Lock. Test on your real Hyprland session and keep the login password available. This is a real secure lock, not a preview.
