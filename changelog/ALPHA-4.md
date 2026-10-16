# RusticQ Alpha 4 — Release notes

Baseline: latest RC5 runtime/visual fixes. Target: Quickshell 0.3.1 (Arch Linux) and Hyprland.

### Implemented

- All previous release-change Markdown documents consolidated into this `changelog/` directory; project README rewritten for the current release.
- Additional spacing between bar Wi-Fi and Battery indicators; no rearrangement of the audio/Bluetooth indicators.
- Optional **Show running apps** in Dock settings. Window list from `Hyprland.toplevels.values`, deduplicated by `appId`, icon from `DesktopEntries.heuristicLookup()` or app ID, click calls `.activate()`. Off by default. Dock scrolls horizontally if needed.
- Launcher reduced to one frame: `MiniLauncher` is the only card drawn in the centered overlay.
- Persistent Quick Control order via `SettingsStore.quickControlOrder`, with edit/reorder grip and drag gestures. Supports Wi-Fi, Bluetooth, Battery, always-open System, Notifications. Reset order restores defaults.
- Notifications adopts shared `SectionHeader` with the same icon, title, chevron, spacing and outer border as other dropdown cards.

### Validation and limitations

The code may be statically checked offline; actual popup positioning, drag interactions, dock window activation, and layer behavior need testing under your compositor. Quickshell 0.3.1 is the compatibility target.

For a new test install, extract the archive into a fresh directory and run `qs -p .` inside `quickshell/`.
