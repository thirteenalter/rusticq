# Quickshell 0.3.1 — compatibility notes

Environment confirmed by user: `Quickshell 0.3.1 (revision , distributed by Arch Linux)`.

## Verified sources

- https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/
- https://quickshell.org/docs/v0.3.1/types/Quickshell/Variants/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/Hyprland/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Network/
- https://quickshell.org/changelog/

## Changes relative to hotfix1

1. `modules/bar/BarWifi.qml`: Unknown security is no longer automatically blocked; try the built-in NetworkManager connection first, because v0.3.1 can mislabel open networks as Unknown. If credentials are required but the security type is still Unknown, the UI points to NetworkManager rather than attempting an invalid PSK call. No passwords are guessed or bypassed.
2. `services/WifiManager.qml`: report `Security unknown` rather than claiming the network definitely requires a password.
3. README and development baseline switched to upstream v0.3.1. No changes to original Gruvbox palette, fonts, or bar geometry.

## Startup hotfix from the preceding ZIP

`modules/main/Bar.qml` does not instantiate `PowerButton { targetScreen: ... }`; the toggle reads `barWindow.screen` directly. If you still see a `targetScreen` load error, you are launching an older file copy.

## Install into your existing dev path

```bash
# Back up your current tree first, from your own terminal
cp -a /home/ryznxx/dev/quickshell "/home/ryznxx/dev/quickshell.bak.$(date +%Y%m%d-%H%M%S)"
# Extract the ZIP, and copy the contents of the included quickshell/ folder
# into /home/ryznxx/dev/quickshell/.
qs -p /home/ryznxx/dev/quickshell
```

## Quick checks

```bash
quickshell --version
grep -n 'targetScreen' /home/ryznxx/dev/quickshell/modules/main/Bar.qml
qs -p /home/ryznxx/dev/quickshell
qs log -f
```

The `grep` command for `modules/main/Bar.qml` should print **nothing**; it must not contain a `PowerButton { targetScreen: ... }` binding. If startup still fails, share the next QML error with filename and line number.

**Runtime not verified** — tests require an actual Hyprland/Wayland session with Quickshell 0.3.1, a Wi-Fi device, and NetworkManager.
