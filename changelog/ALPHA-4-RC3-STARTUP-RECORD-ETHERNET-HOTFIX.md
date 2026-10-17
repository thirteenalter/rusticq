# RusticQ Alpha 4 RC3 — Startup, Share Recording & Ethernet Hotfix

Version remains **Alpha 4 RC3**. No release bump.

## 1. Appearance startup fix

`modules/settings/pages/SettingsAppearancePage.qml` included a stray property assignment at line 331:

```
color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
```

The `font` property was being assigned on a layout, not a `Text` component. The closing `}` was also misplaced, so the fix removes that stray assignment and closes the root `ColumnLayout` at the end. This resolves the known cascade `SettingsAppearancePage unavailable → SettingsWindow unavailable → shell config failed`.

## 2. Share screen recording

The Share menu now includes:
- **Record screen** (select monitor with `slurp -o`)
- **Record region** (select region with `slurp`)
- **Record with audio** (select monitor, record input audio through `wf-recorder --audio`)
- **Stop recording** while an active recording exists
- **Open recordings** (`~/Videos/RusticQ`, or `$XDG_VIDEOS_DIR/RusticQ`)
- **Screen sharing portal** diagnostic

Uses `scripts/rustiq-record.py` and singleton `services/ScreenRecorder.qml`. The helper saves MP4 files locally, tracks a process safely, refuses duplicate start commands, and stops only the process it launched. Requires `wf-recorder` and `slurp` for recordings.

For native live/meeting screen sharing, Chromium/Firefox and other compliant applications request the **XDG ScreenCast Portal**. The **xdg-desktop-portal-hyprland** service displays the Hyprland selector automatically when an application requests a share. RusticQ does not impersonate or bypass that consent dialog. The diagnostic action checks the relevant user services, but does not modify portal configuration.

Arch package dependencies (install if not already present): `wf-recorder`, `slurp`, `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`.

## 3. Ethernet information popup

`WifiService.qml` now reads active wired connections through `Quickshell.Networking` (`DeviceType.Wired`, link up, connected). When connected over Ethernet, the bar indicator shows a cable and clicking it opens **MiniEthernetInfo.qml** instead of Wi-Fi controls. The panel shows interface name and link speed if available.

This changes **only the bar's shortcut** while Ethernet is connected: Wi-Fi can still be configured separately through Quick Control/NetworkManager. A wired connection does not technically make simultaneous Wi-Fi configuration impossible.

## Testing

- `python3 tools/test_rc3_runtime_record_ethernet_fix.py` — mocks wf-recorder/slurp and verifies start/status/stop/duplicate protection, checks QML wiring.
- `python3 tools/test_rc3_ai_audio_appearance_fix.py` — existing RC3 static regression.
- Local delimiter checks on all QML files.

Desktop-runtime validation still needed for Quickshell 0.3.1/Hyprland, actual video encoding, and portal application requests.
