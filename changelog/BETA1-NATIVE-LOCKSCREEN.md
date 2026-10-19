# Beta 1 · Native WlSessionLock / PAM Lock Screen

- Standalone QML lock config (`lockscreen.qml`, `modules/lock/RusticQLockSurface.qml`) with custom RusticQ appearance and multi-monitor surfaces.
- One PAM auth context; only `PamResult.Success` permits unlock, `WlSessionLock` is never unset for failed credentials.
- Safe single-instance launcher and log file; no auto-fallback if compositor may have locked the session.
- Power Menu, IPC/shortcut Lock and Settings Appearance Lock now call native launcher.
- Hyprlock remains available manually using `scripts/rusticq-native-lock.py legacy`. Original Omarchy ASCII screensaver left intact.
- Offline tests cover credential gating, source wiring, launcher preflight, and safe packaging. Real PAM/Wayland behavior requires testing on target machine.
