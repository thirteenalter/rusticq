# RusticQ Alpha 4 RC4 — Top Bar Shortcuts (v4)

Two archives are provided: **FULL** and **PATCH**. They contain no installer.

## Install by extracting, without scripts

- FULL ZIP has the top-level `quickshell/` folder. Extract it into `~/dev/` so its files overwrite `~/dev/quickshell/`.
- PATCH ZIP contains paths relative to the RusticQ project root. Extract it **inside** `~/dev/quickshell/` and approve overwrite. PATCH targets the previous RC4 v3 focused-monitor/all-actions release.
- Restart RusticQ with `cd ~/dev/quickshell && qs -p .`.
- These ZIPs update only the source code. Neither enables permanent Omarchy integration nor edits existing Hyprland shortcut configuration when extracted.

## New shortcut functionality

- Settings > Keyboard Shortcuts > **Top bar button shortcuts**: choose one of 16 interactive top-bar elements, then its specific action, key combination, Apply override, or Restore selected.
- The `Menus` bar element exposes individual menu buttons (File/Edit/View/Share/Shell/Tools) **and their previously available sub-actions**.
- The `Workspaces` element exposes workspace actions 1–10, including the 1–6 buttons shown on the top bar.
- The `Quick Modes` element exposes **Reveal Quick Modes** plus individual mode toggles.
- The `Network` element exposes **Auto Wi-Fi / Ethernet** (matches the clicked indicator) plus separate Wi-Fi and Ethernet actions.
- Logo -> Settings; Arch icon -> AI; search icon -> Launcher; Weather, Clock, Calendar, Bluetooth, Battery, Audio and Task indicators -> respective popups; Microphone indicator -> microphone mute toggle; sliders icon -> Quick Control.
- Download and upload throughput gauges are not clickable buttons in RC4, so they are shown as passive indicators rather than fake shortcut targets. For activity details use System Monitor.
- Actions can be bound even when their corresponding bar icon is hidden. The **Reveal Quick Modes** action only reveals an existing Quick Modes component, so enable the icon for that particular action.
- All keyboard invocations use the existing focused-monitor routing (Hyprland), with default Omarchy Lua unchanged. Revert removes the chosen managed override; backups of the original shortcut lines are preserved for auditing.
- Existing shortcut action IDs remain unchanged, and saved overrides from v3 are compatible.

## Tests / limits

Automated backend tests cover: 77 registered actions, all 16 top-bar groups, duplicate-key rejection, reversible shortcut overrides, Omarchy config snapshots, and simulated enable / restore flows.

A live multi-monitor Hyprland session and Quickshell runtime were not available in the build environment. If a new shortcut fails, inspect `qs -p .` and Hyprland logs before enabling permanent integration.

`FULL` intentionally excludes Git history and embedded font binaries. When overwriting an existing RusticQ folder, keep your current `assets/*.ttf` files intact; patch never touches them.
