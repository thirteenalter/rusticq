# Surface alignment, Wi-Fi and shared spacing

Implemented without a release version change. Padding controls are under **Settings → Appearance → Surface Spacing** and appear in settings search. They work with Standard UI, Aether, RAGE Adaptive and RAGE Exclusive, with glass on or off.

## What changed

Legacy launcher titles now fill their text column and align beside the logo. Search backgrounds use the same outer inset as results, retain the configured input height, and no longer lose vertical space to half-padding. Clean Hover releases its former unused minimum height. Launchpad and Overview have a centered, bounded search surface with a search icon, “Search your applications…” placeholder and Escape hint. Overview shows scrollable, icon-based shortcuts only when favorites or recent applications exist; otherwise its grid receives the entire width.

Wi-Fi puts connection status under its title and the power switch in the header. Search and scan share one row, networks have quiet hover/selection surfaces, the connected network has a check, and advanced/portal navigation lives in the footer. Connection, disconnection, password entry, public portal visibility, hidden networks, device settings and focus acquisition still use the existing services and handlers. Network rows and the power switch also support keyboard/accessibility activation. No network connection was changed during validation.

## One inset owner

`Theme.qml` resolves all shared spacing from density and optional validated settings. `sectionPadding` and `sectionGap` remain compatibility aliases. A content component owns its inset; its window/Loader must not add another inset around that same content. IndicatorPopup previously added 8px around already-padded clock, calendar, weather, menu and dashboard components. That inset and its corresponding 16px height allowance are removed. Intrinsic widget, toast and Quick Control heights use the effective insets rather than unrelated constants.

| Active surface family | Content policy |
| --- | --- |
| Wi-Fi, Bluetooth, battery, audio, weather, time/date, Ethernet, notifications, context menu | Shared panel inset; popup Loader adds zero; lists and long bodies retain scrolling |
| Quick Control | Panel inset, shared gaps, inset-free top header, individually padded cards; collapsed card/system heights derived from density/insets |
| Settings and device settings | Window/content inset; SettingsSection owns its own section inset; nested sidebar and controls use their respective roles |
| Desktop clock/calendar/system/media/weather/network, notes, scratchpad, Kanban and random image | Shared content inset and corresponding intrinsic-height allowance; graph cards use nested-card padding |
| AI, monitor/dashboard/task view, OSD, notification toasts | Shared content inset; no second task-window inset around the already-padded dashboard |
| Power, package/backup confirmation, authorization, Polkit and Wi-Fi QR | Shared panel/dialog content role; authentication, focus and credential handling unchanged |
| Bar and Dock | Existing geometry and user-specific spacing remain independent; decorative visibility still preserves content geometry |
| Launcher | Existing `launcherPadding` still owns outer geometry; shared control/gap tokens refine internal alignment without replacing saved launcher settings |
| Session lock and legacy prototypes | Secure opaque lock background and lock geometry preserved; inactive prototypes are not restyled as active windows |

This is content spacing. Icon artwork insets, shadow extents, chart geometry, screen-edge placement and user-configured bar/Dock geometry are different roles and are not replaced with panel padding.

## Manual controls and persistence

| SettingsStore key | Range | Auto, comfortable / compact |
| --- | --- | --- |
| `surfacePanelPadding` | -1, 0–32 | 16 / 12 px |
| `surfaceCardPadding` | -1, 0–24 | 12 / 10 px |
| `surfaceControlPadding` | -1, 0–20 | 12 / 8 px |
| `surfaceContentGap` | -1, 0–24 | 12 / 8 px |
| `surfaceInlineGap` | -1, 0–16 | 8 / 6 px |

`-1` follows UI density; `0` is a real manual value. Dialog padding derives from panel padding plus inline gap. All five defaults are Auto, so legacy configurations migrate without a forced manual size. Enums are unnecessary; only integer values in these ranges are accepted. Invalid strings, booleans, nulls, fractional and out-of-range numbers are rejected.

Sliders use preview/commit: dragging changes live properties without writing JSON on every move; release or keyboard adjustment persists through the existing SettingsStore FileView/settingsSnapshot. Per-row Auto and Reset Surface Spacing restore density defaults without touching launcher/bar geometry, palette, material, visibility or other preferences. External spacing-only JSON changes update bindings without a shell reload. The example JSON documents defaults; deployment never overwrites the user's JSON.

## Validation actually performed

- QML: launcher **14/14**, Wi-Fi/audio **19/19**, shared spacing **3/3** including **198 production geometry combinations**, validation, manual keyboard controls, preview/commit, Auto/reset and restart persistence.
- QML regressions: weather **7/7**, motion **10/10**, Quick Modes **6/6**, RAGE UI **10/10**, native palette **7/7**, bar surfaces **8/8** including 64 visibility combinations, all 5 layouts × 4 edges and two simulated monitors.
- Same-engine reload: production MiniLauncher is compiled through settings-triggered reload, atomic source swaps, remote IPC reload and recovery from an intentionally invalid QML update. A launcher-local inline type initially passed cold starts but failed in the long-lived shell; it now uses a standard Component delegate and passes this reload test.
- Wayland: Wi-Fi/Bluetooth native keyboard/focus **3/3**; launcher/Dock motion **6/6**. The stable native animation canvas, warmed launcher and retained Dock contents remain intact.
- Actual screenshots: legacy launchers, Launchpad, Overview with/without shortcuts; Wi-Fi and widgets; Appearance spacing controls; Quick Control. Launcher captures retain one controller/editor across styles. Existing pixel checks pass for None backdrop and Dock halo behavior; compositor global blur values remain unchanged.
- Static: source/import validation, bar modes, settings refactor, launcher contracts/providers, RAGE contracts, compositor safety/UI, portable settings, notification layout, system monitor, native lock structure/design and Wi-Fi QR layout.

Runtime: Quickshell 0.3.2, Hyprland 0.56.2, one 1920×1080 display at scale 1. Baseline compatibility remains Quickshell 0.3.1. Native tests use private namespaces, owned temporary rules, isolated preferences and fixture network/weather/media data. No compositor configuration, wallpaper, production network state or global blur setting is changed. Offscreen native device-service availability warnings do not constitute real hardware testing; those services are validated with fixtures. Actual monitor hotplug, different fractional scales, physical Wi-Fi authentication and every possible padding combination still need user-specific verification.

## Evidence

Production file inventory and validation/deployment records: [audit directory](audit/surface-spacing/). The installed shell was already partially synchronized through its local updater during work; original comparisons therefore use its pre-update backup, not the partially updated installed tree. Residual deployment used hash guards, backup and reload of the existing process. Preferences were byte-identical afterward.

- [Original legacy launcher](audit/surface-spacing/launcher-before.png) · [aligned launcher](audit/surface-spacing/launcher-after.png)
- [Launchpad](audit/surface-spacing/launchpad.png) · [Overview with shortcuts](audit/surface-spacing/overview.png)
- [Wi-Fi before](audit/surface-spacing/wifi-before.png) · [Wi-Fi and widgets after](audit/surface-spacing/wifi-after.png)
- [Manual padding settings](audit/surface-spacing/appearance.png) · [Quick Control](audit/surface-spacing/quick-control.png)

Manual checks: change each spacing slider and Auto/reset; reopen popups; search and type in every launcher family; test Overview without favorites/recents; expand a Wi-Fi row and password/advanced form; check RAGE off/Adaptive/Exclusive; retain custom bar/launcher padding; restart and verify saved values. To inspect the active instance use `qs list --all`; reload the existing installed shell through its IPC instead of starting a second full shell, which competes for Notifications, Polkit and portal registration.
