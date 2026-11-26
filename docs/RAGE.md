# RAGE — RUSTIQ ADAPTIVE GLASS ENGINE

Implemented for RusticQ Beta 4 on the Quickshell 0.3.1 API baseline. This feature
does not change the release version. It is a presentation layer over the
existing Theme, settings, services and motion system.

## Using RAGE

Open **Settings → Appearance → Glassmorphism** and enable **Enable
Glassmorphism**. Open windows and newly loaded panels use the same reactive
tokens; selecting a preset or moving a slider does not recreate the shell.
Slider preview updates memory; releasing it or using the keyboard commits JSON.
Other glass customization controls are disabled with the master off, retaining
their values. Reset Glass Settings restores all glass defaults, including off.

| Preset | Opacity | Tint | Border | Shadow | Character |
| --- | ---: | ---: | ---: | ---: | --- |
| Frosted | .44 | .10 | .16 | .14 | Neutral frosted base and restrained edges |
| Crystal | .24 | .05 | .14 | .10 | Clearer base with thin specular lighting |
| Tinted | .50 | .30 | .16 | .14 | More local contrast; native tint stays neutral |

Presets enable highlights and shading, leaving the provider, palette, geometry,
visibility, master, blur and performance choices alone. Saved custom values are
never migrated to these defaults automatically. Crystal is glass-inspired;
there is no optical refraction or claim of Apple's Liquid Glass implementation.

**Gruvbox + Standard, Gruvbox + Glass, Aether + Standard and Aether + Glass** all
use the existing palette source. Aether still reads
`~/.config/aether/theme/colors.toml` live; unavailable Aether falls back to
Gruvbox. No second wallpaper color extractor is introduced. **RAGE Exclusive**
selects a third provider, RAGE Native, inside the same Theme resolver. Obsidian is
the default native palette; Pearl, Pure Crystal and Graphite Frost are also
available. Native constants never derive from Gruvbox/Aether, even on solid
surfaces. The saved external source is restored by selecting Adaptive. Provider
controls stay available with glass off; Reset Glass Settings preserves provider
and native palette. Existing installations without a mode keep Adaptive behavior.
See [material reconstruction and visual evidence](RAGE-MATERIAL-RECONSTRUCTION.md).

## Independent bar surfaces

**Settings → Bar → Surface Styling** and **Appearance → RAGE · Surface Glass
Effects · Bar** instantiate the same editor and settings keys. These controls
remain usable while RAGE is disabled.

- **Bar Container** controls the full rail fill and decorative outline.
- **Bar Segments** controls the existing floating groups in Separated layout.
  Other modes retain their original group structure and spacing.
- **Individual Modules** controls permanent item backgrounds and outlines.
  Active workspace markers, hover, selection, status and keyboard focus remain
  functional when decorations are hidden.

All five layouts and Top/Bottom/Left/Right support visibility and bar materials.
No parent opacity, input-region, margin, padding, exclusive-zone or content
visibility changes implement these switches. Auto-hide and recovery remain
separate. Bar glass can be disabled independently of other RAGE surfaces.

| Quick preset | Outer bg/edge | Segment bg/edge | Module bg/edge | Material action |
| --- | --- | --- | --- | --- |
| Original | on/on | on/on | on/on | Native Separated rail remains unfilled |
| Glass Rail | on/on | on/on | on/on | Enable bar glass and explicit Separated rail fill |
| Borderless Glass | on/off | on/off | on/off | Enable bar glass and explicit rail fill |
| Floating Segments | off/off | on/off | off/off | Remove enclosing Separated rail fill |
| Outline Only | off/on | off/off | off/off | Preserve material choices |
| Naked Bar | off/off | off/off | off/off | Preserve material choices |

Presets do not change global RAGE, color source, accent, position, radii or
capsule settings. Layout changes never apply presets. Bar opacity multiplies
only decorative fill alpha; foreground remains opaque. Radii are independent
of the glass style; `-1` follows native layout geometry. Capsule mode is an
explicit geometry override for segments/modules; turning it off restores saved
radii. Hiding a surface never resets geometry.

Professional preserves its original full-width/full-height rail, square outer
corners, thin accent separator and original control layout with default settings.
Glass can change its material without changing that structure. Explicit user
geometry or visibility choices still apply.

The unwanted Separated rectangle came from an originally zero-width outer
border passing through the primary glass helper, which promoted it to one pixel
even when its fill was transparent. BarSurface now resolves fill, outline and
effects independently, preserves the empty native Separated rail and only draws
an enclosing outline when explicitly requested. Outline-off suppresses specular
edges; fill-off suppresses reflections and contact shading. A completely naked
bar has no decorative glass effect loaders.

## Architecture and coverage

`config/Theme.qml` keeps the original opaque base palette and owns semantic
window, primary, secondary, nested card, control, hover, pressed, selected,
popup, tooltip, border, specular, shadow, modal and authentication tokens.
Original expressions remain fallback arguments, so disabling glass restores
standard materials. Independent bar visibility/geometry preferences deliberately
remain effective with glass off.

`config/SettingsStore.qml` owns all persistent values, defaults, validation,
setters, presets and resets, using the existing FileView and settingsSnapshot.
External edits containing only glass/bar-style keys apply live; unrelated edits
retain the existing guarded reload behavior. No new settings file is created.
The actual working user's `user-settings.json` was not replaced by feature defaults.

`GlassSurface` extends Rectangle. Its conditional Loader owns two static,
rounded gradients: a top highlight and bounded soft contact shading. It never
captures desktop content or performs a nested blur pass. `BarSurface` adds
outer/segment/module policies and separate functional feedback. `GlassPreview`
and `BarSurfacePreview` use those real components and Theme tokens.

`services/GlassService.qml` owns runtime capability state and debounced compositor
requests. It reacts to relevant setting changes and Hyprland config reloads,
without a polling loop. A generation token guards destruction after shell reload.
Motion continues to use SurfaceMotion, MotionLoader and existing Theme durations.

| UI family | Integrated surfaces / ownership | Status |
| --- | --- | --- |
| Main bar | Bar, VerticalBarContent via BarZone, Pill, clock/weather/status, Workspaces, Arch, ContextMenuBar, Quick Modes | Covered, five layouts/four edges |
| Dock | Floating canvas, app cards, hover and running selection | Covered; auto-hide/launch logic retained |
| Launcher | LauncherOverlay, MiniLauncher search, categories, results, tools | Covered; keyboard model retained |
| Quick Control | BarWrapper, QuickControlCards, Wi-Fi/Bluetooth/battery/audio/brightness/system/notifications/advanced cards | Covered; native services retained |
| Settings | Floating window, sidebar, search, SettingsSection, every page, device settings and controls | Covered; compositor decoration retained |
| Notifications/popups | Toasts, IndicatorPopup, ContextMenu, tooltip and mini panels | Covered; focus, lifetime/actions retained |
| Desktop widgets | DesktopWidgetWindow calendar/clock/system/media/weather/connectivity and notes/Kanban/random image cards | Covered; workspace/monitor policies retained |
| System utilities | System monitor, OSD, task view, QR, package/shortcut confirmations and power | Covered; action logic retained |
| Cloud AI | Outer panel, messages, input, threads and model controls | Covered; requests/history/lifecycle retained |
| Authentication | NativePolkit view, RusticQLockSurface login card | Covered; opaque security backing/controller retained |
| Legacy | BarMain composition and PackageAuthorizationOverlay | Shared visual tokens; not newly activated |
| Prototype | Unloaded ProcessManager | Audited; not represented as active UI |

The [surface audit](audit/RAGE-SURFACES.md) inventories 99 files containing 526
surface nodes and 25 window nodes (definitions and conditional branches, not
simultaneous instances). Signal colors, graph data, slider handles, QR white
quiet zones, circular indicators and secure backing intentionally preserve
their original contrast. Fonts remain Poppins and Material Symbols.

## Persistent schema

All booleans require actual JSON booleans. Enums must match exactly. JSON load
rejects invalid/out-of-range/non-integer values; legacy/malformed settings use
defaults. Numeric UI setters clamp to valid ranges; `NaN` and infinity are
rejected. Example defaults are in `user-settings.example.json`.

| Key | Default | Allowed values |
| --- | --- | --- |
| glassmorphismEnabled | false | boolean |
| rageMode | adaptive | adaptive / exclusive; independent of glass |
| ragePalette | obsidian | obsidian / pearl / pure-crystal / graphite-frost |
| glassStyle | frosted | frosted / crystal / tinted |
| glassOpacity | .44 | .15–1 |
| glassBlurEnabled | true | boolean |
| glassBlurRadius | 24 | integer 0–64, retained capability-gated preference |
| glassBorderOpacity | .16 | 0–.60 |
| glassCornerRadius | 20 | integer 0–32 |
| glassReflectionEnabled | true | boolean |
| glassShadowEnabled | true | boolean |
| glassShadowIntensity | .14 | 0–.60 |
| glassTintStrength | .10 | 0–.50 |
| glassPerformanceMode | false | boolean |
| barBackgroundEnabled / barOutlineEnabled | true / true | boolean |
| barSegmentBackgroundEnabled / barSegmentOutlineEnabled | true / true | boolean |
| barModuleBackgroundEnabled / barModuleOutlineEnabled | true / true | boolean |
| barGlassEnabled | true | boolean; still requires global RAGE |
| barRailFillEnabled | false | boolean; optional enclosing Separated rail |
| barOpacity | 1 | .10–1, multiplier of decorative material alpha |
| barCornerRadius | -1 | integer -1–64 |
| barSegmentRadius | -1 | integer -1–64 |
| barModuleRadius | -1 | integer -1–64 |
| barCapsuleGeometry | false | boolean |

`resetGlassSettings()` affects only glass defaults. `resetBarSurfaceSettings()`
affects only bar surface/material/geometry defaults. Neither resets unrelated
settings. The Original bar preset restores visibility/native rail fill while
preserving custom geometry. Preferences persist through normal restart/login.

## Compositor behavior and safety

QML cannot automatically sample application/desktop content behind a window.
RAGE uses compositor-native backdrop blur, with a readable tinted fallback.

| Backend | Behavior |
| --- | --- |
| Hyprland 0.55–0.57 Lua API | Version + named-rule API + global blur probe; exact RusticQ session rules |
| Omarchy Quattro on that API | Same adapter; no Omarchy default/config edits |
| Legacy, future or unknown Hyprland | Tinted fallback; no guessed config syntax |
| Niri | Tinted fallback; QS 0.3.1 lacks ext-background-effect requests and no audited dynamic rule adapter is shipped |
| Missing/ambiguous compositor or failed IPC | Tinted fallback and honest Settings status |

Native validation was on **Hyprland 0.56.2 / Omarchy, Quickshell 0.3.2**.
Other supported Lua versions are capability-gated but were not locally exercised.
Quickshell 0.3.1 compatibility follows the documented API, not a local 0.3.1 run.

Six named session rules are owned by RAGE: `rusticq-rage-layers`,
`rusticq-rage-bar`, `rusticq-rage-windows`, `rusticq-rage-launcher`,
`rusticq-rage-launcher-backdrop` and `rusticq-launcher-presentation`.
Launcher material/backdrop blur are independent; the presentation rule prevents
double compositor/QML animation, including when glass is off, and is released
on owner-guarded service cleanup. See [Launcher Studio](LAUNCHER-STUDIO.md). Layer namespaces are static and
assigned before connection. Exact namespace/title/class matches exclude other
applications, keep-awake, recording indicators and authentication. Bar indicator
panels use the existing `rusticq-popups` layer rule independently of bar blur;
other PopupWindow instances retain their parent popup behavior. FloatingWindow
uses window rules, never a layer rule.

Hyprland's alpha-aware `ignore_alpha=0.02` avoids blurring transparent bar gaps
and fullscreen scrims. The separate bar rule can disable bar backdrop blur while
retaining popup blur. Naked Bar or bar-glass off does not disable Quick Control,
other RAGE windows or global user blur. There is no invented per-QML-item blur
API and no additional segment windows. Very low explicit bar alpha can fall
below the blur threshold. Backends without the audited alpha-aware path use
the refined tinted fallback rather than a full rectangular blur region.

**Blur strength is compositor-owned.** The radius preference is retained for a
future capable backend; no backend currently advertises independent strength,
so its slider is hidden with an explanation. Global blur disabled by the user
stays disabled. RAGE cannot override it without changing the user's global
choice, and never does so.

Rules are updated by stable names, not appended repeatedly. Capability and
configuration-error checks precede applying. Lua failure restores previous
enabled/bar-blur state. Turning off glass disables only owned rules. No config
file, user/default blur setting, sudo, compositor reload/restart or persistent
rule mutation is involved, so no persistent backup file is necessary. Cleanup
is guarded by an owner token to avoid shell-reload races. After a hard kill
where no destructor can run, the next normal startup reconciles owned rules;
the helper's `disable` action can also remove the session effects.

## Performance and security

Performance mode and existing low-memory mode suspend RAGE blur, reflections
and shading without changing the user's preferences. Effect Loaders are
released when off, hidden or unnecessary. No ShaderEffectSource, framebuffer
capture, continuous screenshots, continuous reflection animation, extra GPU
library or second animation engine is introduced. Nested cards use low-alpha
layers rather than separate background blur passes. Soft Shadows controls
bounded contact shading inside surfaces; external compositor window shadows
remain compositor-owned.

Without active blur, primary opacity adapts to at least 86%; tooltips/modals are
denser, and auth surfaces remain opaque. Explicit bar opacity is a user override
of decorative alpha. Text/icon item opacity is not used for glass transparency.
Existing motion opacity only animates entry/exit.

The session-lock window and backing remain opaque over a safe internal
wallpaper/solid background. Login-card shading cannot reveal locked applications.
PAM, secure session-lock release and authorization mechanisms are unchanged.
The QR quiet zone remains white/opaque; no credentials enter settings or logs.
Confirmation Escape handlers are attached to their visual Item, preserving
keyboard cancellation without invalid FloatingWindow Keys attachments.

## Validation results

Executed in this workspace on 2026-11-24:

| Check | Actual result |
| --- | --- |
| `verify-static.py` | PASS, 155 QML files, zero issues |
| `check-bar-modes.py` | PASS, five modes, persistence and shared geometry |
| `test_glassmorphism.py` | PASS, 17 offline settings/source/backend safety tests |
| `test_glassmorphism_ui.py` | PASS, 8 UI scenarios plus initial test case, save/reload and three legacy/invalid JSON cases |
| `test_bar_surfaces_ui.py` | PASS, 7 UI scenarios plus initial test case; 64 visibility combinations, five modes × four edges, two simulated monitors, Professional compatibility, presets and reload |
| `test_motion_ui.py` | PASS, 9 results and persistence reload |
| `test_bar_padding_ui.py` | PASS, five modes × four edges, two screen sizes, icon sizes/padding, controls and reload |
| `test_settings_refactor.py` | PASS |
| `test_portable_user_settings.py` | PASS, 6 tests |
| `test_compositor_studio_safety.py` | PASS, 29 tests; isolated session desktop environment |
| `test_compositor_studio_ui.py` | PASS |
| `test_native_lock_qml_structure.py` | PASS |
| `test_native_lock_design_alignment.py` | PASS, 3 tests |
| `test_builtin_polkit_agent.py`, `test_rusticq_native_lockscreen.py` | PASS |
| `test_wifi_audio_ui.py` | PASS, 16 results |
| `test_quick_modes_ui.py` | PASS, 6 results |
| `test_cloud_ai.py` | PASS, offline provider mocks |
| `test_dock_launcher_layout_fix.py`, `test_system_monitor_fix.py` | PASS |
| `test_wifi_qr_fullscreen_layout.py` | PASS, 4 tests |
| `test_notification_toast_redesign.py` | PASS, including fontconfig glyph coverage |
| `test_glassmorphism_native.py --run` | PASS, real Wayland surfaces/presets, singleton IPC, bar-specific rule, owner cleanup, isolated real entry point and `qs log` |

Native testing rendered Settings, dock, desktop clock, popup, Quick Control,
power, launcher, AI, notification and OSD; it toggled materials without
recreating Settings. Real shell.qml startup used an isolated tree and stubbed
only conflicting Polkit ownership, wallpaper restore and QR helper actions.
It did not perform power actions, lock the real session, authenticate, install
packages or change device connections. The existing desktop notification server
caused an expected duplicate-registration warning in the temporary instance.
Offscreen sandbox runs also log IPC-server denial; QML assertions still ran.

Global compositor blur was **off** in the test session. Named Lua rule updates
were accepted; blur enabled/size/passes were identical before and after, all
owned rules were disabled at cleanup and configerrors was empty. This verifies
safe fallback and IPC, **not the visual quality of enabled desktop blur**.
Native software-rendered light/dark preview images were captured in `/tmp`;
offscreen tests also capture the actual bar content against contrasting scene
backgrounds. Those images are QML scene captures, not compositor backdrop-blur
screenshots. Physical monitor hotplug, hardware GPU cost and real authentication
were not exercised. No FPS/CPU/RAM/GPU improvement is claimed from source checks.

The [machine-readable validation record](audit/RAGE-VALIDATION.json) lists the executed commands and exit codes.
The offline RAGE suite is included in source-validation CI. QML/native suites
require local Quickshell, QtTest and a compositor session for the native check.

## Troubleshooting and manual checklist

- Enable RAGE, choose each preset, open already-running Settings/Quick Control
  and a new popup; verify the same palette, readable text and no flicker.
- If blur is absent, read compositor status. Check your own global blur setting
  separately; RAGE leaves it untouched. Refresh compositor support after changes.
- For floating glass groups: Separated → Floating Segments → segment radius 16.
  Check all four edges over bright and dark wallpapers; the rail gaps should
  remain clear without a faint full-width border/blur halo. Open Quick Control
  and confirm its independent material remains intact.
- Select Naked Bar, move through all modes, hover/click workspaces and modules,
  use keyboard shortcuts and reopen menus. Foreground and meaningful feedback
  must remain visible; auto-hide, recovery and exclusive zones should behave
  exactly as before. Professional defaults should retain their original rail.
- Test real second-monitor hotplug, mixed scaling and workspace-specific widgets.
  Simulated two-monitor layout tests do not replace this desktop check.
- Compare enabled compositor blur on actual GPU hardware, including idle CPU,
  RSS and GPU/frame cost. Performance mode should release optional gradients
  and RAGE blur; no heavy QML blur pipeline exists to tune.
- Save, restart RusticQ or log in again and verify glass/bar preferences. Disable
  global glass to return to standard materials; use Original or Reset surface
  settings separately to restore bar decoration defaults.
- Check native lock/PAM and Polkit in a controlled session. This feature does
  not change their security controllers, and automated tests never unlock a
  real session.

Primary API references: [Quickshell 0.3.1 layer-shell namespace](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlrLayershell/),
[Hyprland 0.56 named/window/layer rules](https://wiki.hypr.land/0.56.0/configuring/basics/window-rules/),
[Hyprctl runtime configuration](https://wiki.hypr.land/configuring/core/advanced-configuration/using-hyprctl/),
[Niri window effects](https://niri-wm.github.io/niri/Window-Effects.html).

## File changes

Created components: `GlassSurface.qml`, `GlassHighlight.qml`, `GlassPreview.qml`,
`BarSurface.qml`, `BarSurfacePreview.qml`; settings editors `GlassSettings.qml`
and `BarSurfaceSettings.qml`; service `GlassService.qml`; helper
`scripts/rusticq-glass.py`; tests `test_glassmorphism.py`,
`test_glassmorphism_ui.py`, `test_glassmorphism_native.py`,
`test_bar_surfaces_ui.py`; this guide, the surface audit, validation record and `changelog/RAGE.md`.

Modified core: Theme, SettingsStore, Store, services/qmldir, shell.qml and example
settings. Modified UI: the integrated families in the coverage table and the
linked audit inventory. Modified validation: bar fixture namespace handling,
current lock design contracts, compositor test environment isolation, current
popup/monitor/QR assertions and optional fontconfig glyph check. README,
FEATURES and static-validation CI document and check the feature. An exact
QML file manifest follows below; pre-existing user changes were retained.

- [config/SettingsStore.qml](../config/SettingsStore.qml)
- [config/Store.qml](../config/Store.qml)
- [config/Theme.qml](../config/Theme.qml)
- [components/ActionButton.qml](../components/ActionButton.qml)
- [components/ApplicationAudioMixer.qml](../components/ApplicationAudioMixer.qml)
- [components/Arch.qml](../components/Arch.qml)
- [components/BarZone.qml](../components/BarZone.qml)
- [components/Clock.qml](../components/Clock.qml)
- [components/ContextMenuBar.qml](../components/ContextMenuBar.qml)
- [components/DeviceSettingsButton.qml](../components/DeviceSettingsButton.qml)
- [components/ExtraStatusIcons.qml](../components/ExtraStatusIcons.qml)
- [components/Indicators.qml](../components/Indicators.qml)
- [components/MarginSlider.qml](../components/MarginSlider.qml)
- [components/MotionStylePicker.qml](../components/MotionStylePicker.qml)
- [components/NameSearchField.qml](../components/NameSearchField.qml)
- [components/Pill.qml](../components/Pill.qml)
- [components/QuickModes.qml](../components/QuickModes.qml)
- [components/ScanButton.qml](../components/ScanButton.qml)
- [components/SettingsToggle.qml](../components/SettingsToggle.qml)
- [components/Tooltip.qml](../components/Tooltip.qml)
- [components/Weather.qml](../components/Weather.qml)
- [components/Workspaces.qml](../components/Workspaces.qml)
- [modules/ai/AiWrapper.qml](../modules/ai/AiWrapper.qml)
- [modules/bar/BarAdvanced.qml](../modules/bar/BarAdvanced.qml)
- [modules/bar/BarBattery.qml](../modules/bar/BarBattery.qml)
- [modules/bar/BarBluetooth.qml](../modules/bar/BarBluetooth.qml)
- [modules/bar/BarHeader.qml](../modules/bar/BarHeader.qml)
- [modules/bar/BarMain.qml](../modules/bar/BarMain.qml)
- [modules/bar/BarMonitors.qml](../modules/bar/BarMonitors.qml)
- [modules/bar/BarNotifications.qml](../modules/bar/BarNotifications.qml)
- [modules/bar/BarSystem.qml](../modules/bar/BarSystem.qml)
- [modules/bar/BarWifi.qml](../modules/bar/BarWifi.qml)
- [modules/bar/BarWrapper.qml](../modules/bar/BarWrapper.qml)
- [modules/bar/WifiAdvanced.qml](../modules/bar/WifiAdvanced.qml)
- [modules/bar/WifiHiddenNetwork.qml](../modules/bar/WifiHiddenNetwork.qml)
- [modules/lock/RusticQLockSurface.qml](../modules/lock/RusticQLockSurface.qml)
- [modules/main/Bar.qml](../modules/main/Bar.qml)
- [modules/main/BarRecoveryHandle.qml](../modules/main/BarRecoveryHandle.qml)
- [modules/main/ClockAlarmControls.qml](../modules/main/ClockAlarmControls.qml)
- [modules/main/ContextMenu.qml](../modules/main/ContextMenu.qml)
- [modules/main/DesktopNotesCard.qml](../modules/main/DesktopNotesCard.qml)
- [modules/main/DesktopRandomImageCard.qml](../modules/main/DesktopRandomImageCard.qml)
- [modules/main/DesktopScratchpadCard.qml](../modules/main/DesktopScratchpadCard.qml)
- [modules/main/DesktopWidgetWindow.qml](../modules/main/DesktopWidgetWindow.qml)
- [modules/main/IndicatorPopup.qml](../modules/main/IndicatorPopup.qml)
- [modules/main/LauncherOverlay.qml](../modules/main/LauncherOverlay.qml)
- [modules/main/MiniAudio.qml](../modules/main/MiniAudio.qml)
- [modules/main/MiniDate.qml](../modules/main/MiniDate.qml)
- [modules/main/MiniEthernetInfo.qml](../modules/main/MiniEthernetInfo.qml)
- [modules/main/MiniLauncher.qml](../modules/main/MiniLauncher.qml)
- [modules/main/MiniTime.qml](../modules/main/MiniTime.qml)
- [modules/main/MiniWeather.qml](../modules/main/MiniWeather.qml)
- [modules/main/MonitorGraphCard.qml](../modules/main/MonitorGraphCard.qml)
- [modules/main/NativePolkitAgent.qml](../modules/main/NativePolkitAgent.qml)
- [modules/main/NotificationToasts.qml](../modules/main/NotificationToasts.qml)
- [modules/main/PackageAuthorizationOverlay.qml](../modules/main/PackageAuthorizationOverlay.qml)
- [modules/main/PackageConfirmationWindow.qml](../modules/main/PackageConfirmationWindow.qml)
- [modules/main/RusticDock.qml](../modules/main/RusticDock.qml)
- [modules/main/ShortcutBackupConfirmationWindow.qml](../modules/main/ShortcutBackupConfirmationWindow.qml)
- [modules/main/SystemDashboard.qml](../modules/main/SystemDashboard.qml)
- [modules/main/SystemMonitorWindow.qml](../modules/main/SystemMonitorWindow.qml)
- [modules/main/SystemOsd.qml](../modules/main/SystemOsd.qml)
- [modules/main/TaskViewWindow.qml](../modules/main/TaskViewWindow.qml)
- [modules/main/WifiShareOverlay.qml](../modules/main/WifiShareOverlay.qml)
- [modules/power/PowerMenu.qml](../modules/power/PowerMenu.qml)
- [modules/process/ProcessManager.qml](../modules/process/ProcessManager.qml)
- [modules/quickcontrol/QuickControlCards.qml](../modules/quickcontrol/QuickControlCards.qml)
- [modules/settings/DeviceSettingsWindow.qml](../modules/settings/DeviceSettingsWindow.qml)
- [modules/settings/SettingsSection.qml](../modules/settings/SettingsSection.qml)
- [modules/settings/SettingsWindow.qml](../modules/settings/SettingsWindow.qml)
- [modules/settings/pages/BarAlignmentEditor.qml](../modules/settings/pages/BarAlignmentEditor.qml)
- [modules/settings/pages/BarIconSizeEditor.qml](../modules/settings/pages/BarIconSizeEditor.qml)
- [modules/settings/pages/BarPaddingEditor.qml](../modules/settings/pages/BarPaddingEditor.qml)
- [modules/settings/pages/BarSpacingEditor.qml](../modules/settings/pages/BarSpacingEditor.qml)
- [modules/settings/pages/ClockSettingsEditor.qml](../modules/settings/pages/ClockSettingsEditor.qml)
- [modules/settings/pages/RecordingIndicatorSettings.qml](../modules/settings/pages/RecordingIndicatorSettings.qml)
- [modules/settings/pages/SettingsAIPage.qml](../modules/settings/pages/SettingsAIPage.qml)
- [modules/settings/pages/SettingsAboutPage.qml](../modules/settings/pages/SettingsAboutPage.qml)
- [modules/settings/pages/SettingsAppearancePage.qml](../modules/settings/pages/SettingsAppearancePage.qml)
- [modules/settings/pages/SettingsBarPage.qml](../modules/settings/pages/SettingsBarPage.qml)
- [modules/settings/pages/SettingsCompositorPage.qml](../modules/settings/pages/SettingsCompositorPage.qml)
- [modules/settings/pages/SettingsHomePage.qml](../modules/settings/pages/SettingsHomePage.qml)
- [modules/settings/pages/SettingsInfoPage.qml](../modules/settings/pages/SettingsInfoPage.qml)
- [modules/settings/pages/SettingsIntegrationPage.qml](../modules/settings/pages/SettingsIntegrationPage.qml)
- [modules/settings/pages/SettingsLauncherPage.qml](../modules/settings/pages/SettingsLauncherPage.qml)
- [modules/settings/pages/SettingsModulesPage.qml](../modules/settings/pages/SettingsModulesPage.qml)
- [modules/settings/pages/SettingsNotesPage.qml](../modules/settings/pages/SettingsNotesPage.qml)
- [modules/settings/pages/SettingsShortcutsPage.qml](../modules/settings/pages/SettingsShortcutsPage.qml)
- [modules/settings/pages/SettingsUpdaterPage.qml](../modules/settings/pages/SettingsUpdaterPage.qml)
- [modules/settings/pages/SettingsWidgetsPage.qml](../modules/settings/pages/SettingsWidgetsPage.qml)
