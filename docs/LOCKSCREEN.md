# RusticQ Native Lock Screen · Quickshell + WlSessionLock + PAM

RusticQ now uses a dedicated Quickshell configuration `lockscreen.qml` for **real Wayland session locking**, not a transparent overlay. It is independent of the desktop `shell.qml`; losing the desktop shell does not automatically unlock the session. It uses the `WlSessionLock` protocol and Quickshell `PamContext` with the **existing** `/etc/pam.d/login` authentication policy; no custom PAM files, password databases, and no root shell operations.

## Entry points

- Power Menu → Lock (confirm twice): closes the power overlay before launching the dedicated locker.
- `qs ipc call rusticq lock` or existing Shortcut Manager action `lock`.
- Settings → Appearance → RusticQ Lock Screen → **Lock now**.
- CLI: `python3 scripts/rusticq-native-lock.py start`.

## Safety and recovery (read before testing)

1. Test in a disposable Hyprland session, with TTY access and the Linux password available. Locking is **real**, not a preview.
2. `python3 scripts/rusticq-native-lock.py prepare` checks prerequisites without locking.
3. If `qs` exits after the session lock has been granted, the compositor may leave the session securely locked but without a usable UI. **Do not repeatedly start other session lockers**: only one may hold the lock. Recover from a trusted TTY or restart the session. This cannot be guaranteed to recover without session disruption.
4. Logs are user-private at `$XDG_RUNTIME_DIR/rusticq-native-lock/native-lock.log`.
5. Emergency legacy locker is only an explicit option *before* native locking: `python3 scripts/rusticq-native-lock.py legacy`; that command uses the existing RusticQ Hyprlock config. Do not run it to escape an active native lock.
6. `omarchy-launch-screensaver force` remains separate under Power Menu → Screensaver; it does not replace the secure lock protocol.

## Behavior and appearance

- WlSessionLock covers every output with a dedicated `WlSessionLockSurface`. Multi-monitor means multiple presentation surfaces but **one PAM context** shared by all monitors.
- Appearance → Lock background: Solid or Current Wallpaper. The selected wallpaper should be a readable local file. Color accents follow the existing RusticQ setting.
- The lockscreen uses the **same** `Theme` singleton (`background`, `surface`, `accent`, `foreground`, `muted`, `borderaccent`) and `Fonts` singleton as the MiniLauncher, Settings, and Power Menu. This covers Gruvbox and opt-in Aether colors, preferred font, font scale, border thickness, and corner radii in the independent lock process.
- A centered clock, the same one-pixel section card border, matched icon/text columns, outlined password field and accent primary button form a single UI hierarchy. Short-screen displays omit decorative header/footer, not the password form.
- The appearance preview is a **visual-only** mini rendering; password entry and unlock are available only inside the real Wayland lock surface.
- Clock, date, login card, messages and keyboard input are native QML. No screenshot/remote unlock, no password logging, and no unlock without `PamResult.Success`.
- When PAM reports an additional challenge, the UI requires another explicit user response; it never assumes an extra prompt is satisfied.
- No automatic fallback after native locker launch: auto-fallback could create a second locker and cause a deadlock if the compositor already locked the session.

## Platform notes

Developed for Quickshell **0.3.1+** and Hyprland Wayland. Quickshell 0.3.2 fixed bugs around PAM subprocesses and session-lock reentrancy; updating to 0.3.2 or later is recommended if you encounter those problems, but test the rest of RusticQ for compatibility. This code has not been subjected to an independent security audit or tested live on your Omarchy machine. Do not enable native locking on critical sessions until you have tested crash behavior, additional monitors, suspend/resume, and login policy.

Primary API references:
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlSessionLock/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pam/PamContext/
