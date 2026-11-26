# Quick Control: Classic, Modular and Frameless

Select **Settings → Appearance → Quick Control**. Existing installations and
settings without the new keys continue using **Classic**. No preferences in
`user-settings.json` are overwritten by this implementation.

**Modular** uses independent connectivity tiles, pill sliders, quick actions,
media controls and metric widgets, with an optional panel background/outline.
**Frameless** uses the same modules and always removes the main background and
outline. Changing modes, density, spacing, colors or radii updates immediately.

## Active architecture

```text
shell.qml → BarWrapper.qml
  ├─ BarHeader.qml
  ├─ QuickControlCards.qml
  │   ├─ Classic: existing card/accordion implementation
  │   ├─ ModularQuickControl.qml
  │   │   ├─ Wi-Fi and Bluetooth tiles
  │   │   ├─ Battery and power tiles
  │   │   ├─ Sliders, quick actions and media
  │   │   ├─ BarSystem → QuickControlSystemMetrics
  │   │   └─ Notifications → scoped BarNotifications
  │   └─ BarAdvanced.qml: Classic cards or Audio / Display / Media tabs
  └─ Advanced navigation
```

`BarMain.qml` is not used by this entry point and is not redesigned.

The connectivity icon toggles its native service. The tile detail area opens the
existing floating device settings window, with the existing screen selection and
focus handoff. Detailed Wi-Fi, Bluetooth and battery management therefore retain
their full-width controls rather than being compressed into a half-width tile.
Wi-Fi scanning, authentication, hidden networks, portals, QR sharing and the
Advanced-only Speed Test keep their existing implementations. Ethernet status
uses `WifiService` and its existing indicator/settings interfaces remain intact.

The five reorder identifiers remain `wifi`, `bluetooth`, `battery`, `system`,
`notifications`. The `system` group includes the system controls and live metric
widgets, without an enclosing surface. Permanent Repeater identifiers preserve
instances; the saved order changes grid coordinates. Drag targets use the actual
centers of visible modules in both dimensions. Handles also support left/right
keyboard movement. Reset appearance does not reset module order.

Quick Control and Advanced each own one scrolling viewport. Optional loaders use
`visible: active`; hidden notification content leaves the layout. System metrics
use four columns when the available width/text scale permits, with a two-column
fallback. Empty modular display previews release their space. Wrapper height
uses the active page's preferred content height and available screen height.

## Services and scoped presentation

- `BrightnessService.qml` owns one backlight reader and one debounced writer.
  Quick Control and Advanced observe that same state. It reads only while a page
  containing brightness is open; unavailable hardware and permission failures
  have explicit states. Opening Display never applies a monitor configuration.
- Existing PipeWire nodes and tracking remain the audio source. Scoped sliders
  support 0–150% and retain a higher observed range when an existing stream is
  already amplified further. Opening the page never writes or clamps volume.
  The existing native/fallback peak monitors remain in `ApplicationAudioMixer`.
- `ApplicationAudioMixer.framelessQuickControl`,
  `BarSystem.framelessQuickControl`, `BarNotifications.framelessQuickControl`
  and `BarMonitors.framelessQuickControl` default to false. Their standalone
  popups, Settings and MiniAudio keep the existing appearance.
- MPRIS playback controls check capabilities. Seeking appears only with seek,
  position and length support. A one-second position notification is active only
  while the visible detailed player needs it; there is no continuous render loop.
- `SysMonService`, `WifiManager`, `WifiService`, `BluetoothService`,
  `BatteryService`, `QuickModesService` and `NotificationCenter` retain ownership
  of their integrations. No duplicate system/network polling or new dependency
  is introduced. `ControlSlider.qml` is not changed.

## Theme, glass and input regions

`QuickControlStyle.qml` resolves only Quick Control preferences through existing
Theme colors, including Gruvbox, Aether, RAGE Adaptive and RAGE Exclusive. Each
interactive surface has one rectangle. Layout containers and section headers
are transparent. Component defaults are 94% opacity, with 98% hover opacity,
so application text behind a control does not compete with its labels. Hover
never reduces the resting opacity. Standard surfaces use `Theme.surface`;
RAGE surfaces use its resolved tint, with a restrained optional accent mix.
Text has a scoped contrast shadow. Parent opacity is used only
by the existing presentation animation, not to make backgrounds transparent.

Frameless/transparent Modular windows use namespace
`rusticq-controls-transparent`, outside the existing RAGE whole-layer blur rule.
They use a clean translucent material fallback. There is no component-local
desktop blur claim, extra blur shader, full-window backdrop, or compositor
configuration edit. A user's own broad compositor rule can still affect the
window; RusticQ does not rewrite that rule. Modular with a visible panel and
Classic keep the existing `rusticq-quick-control` namespace and RAGE integration.

`QuickControlInputMask` builds a union of actual control regions and clips them
through their ancestor viewports. Self-registering surfaces and the scoped
bridge for existing controls keep the list current. Transparent gaps contain no
full-panel MouseArea. `HyprlandFocusGrab`, close/back behavior, screen assignment
and `SurfaceMotion` remain in `BarWrapper`. Pixel-alpha and region tests verify
that the gap between connectivity tiles is both transparent and excluded from
control input rectangles. Actual compositor click-through still needs a desktop
test in an unrestricted session.

## Persistent settings

All keys are in `SettingsStore.qml`, with validated loading, clamped numerical
values, normal save serialization and live external-file updates. New keys are
also documented in `user-settings.example.json`.

| Key | Default | Accepted values |
| --- | --- | --- |
| `quickControlLayout` | `classic` | `classic`, `modular`, `frameless` |
| `quickControlPanelBackground` | false | Boolean; Frameless forces it off |
| `quickControlPanelOutline` | false | Boolean; Frameless forces it off |
| `quickControlComponentBackground` | true | Boolean |
| `quickControlComponentOutline` | false | Boolean |
| `quickControlComponentGlass` | true | Boolean; uses existing RAGE colors when enabled |
| `quickControlAccentTint` | false | Boolean |
| `quickControlSurfaceOpacity` | 0.94 | 0–1 |
| `quickControlHoverOpacity` | 0.98 | 0–1 |
| `quickControlPanelRadius` | 20 | 0–40 px |
| `quickControlComponentRadius` | 16 | 0–32 px |
| `quickControlIconRadius` | 12 | 0–28 px |
| `quickControlComponentSpacing` | 8 | 0–24 px |
| `quickControlSectionSpacing` | 20 | 0–40 px |
| `quickControlPanelWidth` | 400 | 320–560 px; also clamped to screen width |
| `quickControlCompact` | false | Boolean; also follows global compact density |
| `quickControlAnimations` | true | Boolean; also requires global animations |

Classic retains its original geometry/material choices. The independent flags
apply to the two new presentations. **Reset Quick Control appearance** restores
these defaults, including Classic, without resetting other settings or order.

## Files and validation

Main changes: `BarWrapper`, `BarHeader`, `QuickControlCards`, `BarAdvanced`,
scoped variants in `BarSystem`, `BarNotifications`, `BarMonitors` and
`ApplicationAudioMixer`; new `ModularQuickControl`, `QuickControlSystemMetrics`,
`QuickControlMedia`, `BrightnessService`, `QuickControlStyle`, the reusable
`QuickControl*` visual/input components, `QuickControlSettings` and registrations.
The Appearance page/search, SettingsStore, Store and example preferences are
updated. The top bar, launcher, dock, toasts and legacy BarMain are not redesigned.

Validation actually executed:

```bash
python3 tools/verify-static.py
python3 tools/check-bar-modes.py
python3 -B tools/test_quick_control.py
python3 -B tools/test_quick_control_ui.py
python3 -B tools/test_portable_user_settings.py
python3 -B tools/test_settings_refactor.py
python3 -B tools/test_wifi_audio_ui.py
python3 -B tools/test_audio_peak.py
python3 -B tools/test_notification_toast_redesign.py
python3 -B tools/test_system_monitor_fix.py
python3 -B tools/test_beta1_live_displays_confirmation.py
```

New contracts: 5 tests. Production QML: 10 checks plus a separate restart/reset
check. Existing Wi-Fi/audio interactions: 19 checks. QML uses Quickshell 0.3.2,
offscreen software rendering, fixture devices, a fixture backlight executable
and isolated preferences; baseline source compatibility remains 0.3.1. The QML
tests cover mode changes, alpha/input gaps, two-dimensional order and stable
instances, shared amplification/mute, tab navigation, real service bindings with
fixtures, missing devices, media capabilities, small-screen scrolling, palettes,
settings preview/commit and restart persistence. Additional readability coverage
checks text contrast over black/white backdrops for RAGE Graphite Frost and
Pearl with component glass enabled/disabled, plus hover/press opacity stability.

An attempted Wayland `BarWrapper` smoke test was blocked by sandbox display
access (`Failed to create wl_display: Operation not permitted`). Offscreen also
has no PanelWindow backend. This is not verification of native focus grabs,
monitor hotplug, fractional scaling, compositor click-through or physical
devices. The installed shell was not restarted or overwritten. Run the source
in an appropriate Hyprland session and inspect `qs log` for those final desktop
checks; avoid running a second full shell alongside an installed instance.

Render the production components with clearly marked fixture data using
`python3 -B tools/test_quick_control_ui.py --capture-dir /tmp/quick-control-preview`.
The PNGs retain alpha so gaps can be inspected directly.

Fixture renders: [Quick Control](audit/quick-control/frameless-quick-control-fixture.png),
[Audio](audit/quick-control/frameless-audio-fixture.png),
[Display](audit/quick-control/frameless-display-fixture.png).
[Recorded validation](audit/quick-control/validation.json).
