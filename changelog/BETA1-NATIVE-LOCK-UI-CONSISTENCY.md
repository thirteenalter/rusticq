# RusticQ Beta 1 · Native Lock visual consistency

- Rebuilt `modules/lock/RusticQLockSurface.qml` with the existing RusticQ visual language: `Theme` + `Fonts` singletons, one-pixel `Theme.borderaccent`, `Theme.sectionRadius` panels and `Theme.rowRadius` controls.
- Fixed layout columns so the username, password field and unlock action have consistent spacing; matching Power Menu/Launcher design without adding a close or bypass action.
- Header and footer simplify automatically on unusually short outputs; wallpaper dimming uses the current palette instead of hard-coded colors.
- Updated Settings → Appearance preview to show the same hierarchy/appearance as the actual native lock screen. Preview remains noninteractive.
- No changes to PAM policy, controller auth flow, WlSessionLock protocol, desktop processes, user settings, or Omarchy screensaver.
- Offline static tests do not replace a real Hyprland/Quickshell Wayland lock/unlock test.
