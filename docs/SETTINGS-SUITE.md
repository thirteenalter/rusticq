# Unified settings suite

RusticQ Settings and RusticQ Hyprland Settings now share their presentation
components while keeping separate windows, navigation, lifecycle and save
workflows. The default appearance is **Follow RusticQ Theme**. Aether, Gruvbox
and the active RusticQ RAGE palette therefore follow the existing shell
configuration. Independent RAGE Glass Dark/Light and Neutral Dark/Light modes
are optional; Aether palette changes cannot recolor those independent modes.

## Window and page architecture

`components/settings/SettingsWindowFrame.qml` owns the sidebar, titlebar, page
header, search results, content scrolling and contextual footer. Pages own
their group insets. The sidebar scrolls independently and keeps a newly
selected category visible. Narrow windows collapse the sidebar; its button
and search shortcuts expand it again. Back/forward, deep links and lazy page
loading remain available. Both windows remember their normal size.

Native window decorations are retained for move, minimize, maximize and close;
the shared header also supports system dragging and double-click maximize.
No decorative traffic-light controls are presented as working buttons. On the
audited Hyprland adapter, the owned window border is suppressed to avoid a
second outline around the QML frame.

Grouped settings use one surface for related rows, subtle separators and an
aligned control column. The responsive row's width is owned by the page, so
its control width no longer feeds back into parent implicit-width negotiation.
This fixes the repeated `Detected recursive rearrange` warnings.

RusticQ has stable grouped navigation instead of the old All/UI/System filter
and large home cards. Typography, Motion, Wallpaper and Lock Screen show their
own sections. Bar & Dock has a live miniature desktop and Bar/Dock/Behavior
navigation; advanced existing controls remain in a disclosure. Quick Control's
preview respects its actual saved layout and component appearance.

Hyprland uses the same frame, colors, controls and groups. Its overview contains
compact session/configuration rows and real reload, folder, build and backup
actions. Appearance, Effects and Layouts use the existing interactive desktop
preview, with local changes to windows, borders, opacity, gaps and layout.
Animation and gesture previews respect the application's motion preference.
Other existing rule, input, display, shortcut, plugin, editor and backup pages
retain their services and editors inside the shared presentation scope.

## Material and compositor integration

- `SettingsMaterial` resolves shared preferences and optional per-app overrides.
- `SettingsDesignTokens` resolves colors, dimensions, density, motion and material
  capabilities for each application.
- `SettingsGlassSurface` supplies window, sidebar, group, interactive and popover
  surfaces. Alpha applies to their colors, never to the whole window's content.
- `SettingsControlPalette` scopes native control and dialog colors to the suite.
- Existing components find the nearest settings frame through their visual
  parent chain. Outside these windows they continue using `Theme`.

The existing `GlassService` and `rusticq-glass.py` adapter manage exact named
session rules for the two window titles. There is no second blur renderer,
wallpaper capture loop or settings-specific compositor configuration writer.
Owned rules use the shell's exact application class and anchored titles.
Compositor blur strength and global enablement remain under user control.

The reported fallback also exposed a real Lua encoding bug: JSON's default
Unicode escaping emitted `\u00b7` for the middle dot in the RusticQ Settings
title. Lua rejected the expression. Fixed title literals now preserve UTF-8;
a local Lua interpreter test checks syntax, decoded titles and rule flags
against stubbed APIs without connecting to Hyprland.

An unverified or unavailable blur capability uses a nearly opaque readable
fallback and reports that status. The material page also shows the existing
backend's explanation. Popovers have their own stronger material instead of
reusing the almost transparent group surface.

## Persistence

All preferences remain in `config/SettingsStore.qml`; the user's existing
`user-settings.json` is not replaced by this redesign. `user-settings.example.json`
documents the new structure.

| Key | Purpose |
| --- | --- |
| `settingsWindowAppearance.shared` | Shared appearance values; empty means validated defaults. |
| `settingsWindowAppearance.rusticq` | Optional `{enabled, values}` override for RusticQ Settings. |
| `settingsWindowAppearance.hyprland` | Optional `{enabled, values}` override for Hyprland Settings. |
| `rusticSettingsWidth`, `rusticSettingsHeight` | Normal RusticQ window dimensions. |
| `surfaceMaterialOverrides` | Validated overrides for dock, notifications, widgets, popovers and dialogs. |

Appearance values are `mode`, `windowOpacity`, `sidebarOpacity`, `groupOpacity`,
`popoverOpacity`, `outline`, `outlineOpacity`, `outlineWidth`, `radius`, `accent`,
`sidebarWidth`, `density`, `animations`, `iconStyle` and `shadow`. The resolver
uses the shell's material opacity in Follow mode until explicitly overridden.
Ranges, enums, colors and booleans are validated; geometry is clamped. Legacy
non-default Hyprland light/glass/follow preferences migrate to an optional
Hyprland override. Reset restores shared Follow defaults.

Surface overrides contain relevant `inherit`, `glass`, `background`, `outline`,
`opacity` and `radius` values. Turning global glass off preserves those choices.
Bar, Launcher and Quick Control keep their existing dedicated configuration
keys and editors. Interface changes autosave; expensive slider persistence is
debounced. Numeric fields display percentages or pixels and support stepping,
keyboard editing, invalid-input recovery and range clamping.

Hyprland retains staged changes, review/diff, apply/revert, validation, backup,
external-change detection and rollback through `HyprlandConfigService` and
`rusticq-compositor-config.py`. These transactions are not replaced with UI
autosave. Displays and shortcuts keep their existing shared backends and
confirmation workflows. No package is installed and no Hyprland configuration
file is silently rewritten for presentation.

## Added and refactored source

| Area | Files |
| --- | --- |
| New resolver/tokens | `config/SettingsMaterial.qml`, `config/SettingsDesignTokens.qml` |
| Shared window/navigation | `components/settings/SettingsWindowFrame.qml`, `SettingsTitleBar.qml`, `SettingsSidebar.qml`, `SettingsSearchField.qml`, `SettingsCategoryIcon.qml`, `SettingsPageHeader.qml` |
| Shared groups/materials | `SettingsGlassSurface.qml`, `SettingsGroup.qml`, `SettingsRow.qml`, `SettingsDisclosure.qml`, `SettingsPreview.qml`, `SettingsLabel.qml`, `SettingsControlPalette.qml` in the same directory |
| Shared controls | `SettingsButton.qml`, `SettingsToggle.qml`, `SettingsSlider.qml`, `SettingsNumberInput.qml`, `SettingsDropdown.qml`, `SettingsTextField.qml`, `SettingsColorPicker.qml`, `SettingsSegmentedControl.qml` |
| New RusticQ views | `modules/settings/pages/SettingsHomePage.qml`, `SettingsWindowAppearance.qml`, `SettingsSurfaceMaterials.qml`, `SettingsDesktopPreview.qml` |
| Refactored windows | `modules/settings/SettingsWindow.qml`, `modules/hyprsettings/HyprSettingsWindow.qml` |
| Scoped pages/components | `modules/settings/SettingsSection.qml`, existing settings pages, Hyprland overview/page/options/previews and compatibility wrappers; existing shared device/audio controls use scoped colors with a standalone Theme fallback |
| State/material adapter | `config/Store.qml`, `config/SettingsStore.qml`, `config/Theme.qml`, `config/qmldir`, `services/GlassService.qml`, `scripts/rusticq-glass.py` |
| Surface integration | Existing Dock, notification, widget, popup and confirmation surfaces consume the relevant overrides through Theme |
| Validation/documentation | `tools/test_settings_suite_ui.py`, updated Hyprland/settings/material/UI regressions, `user-settings.example.json`, `README.md`, this report and `docs/audit/settings-suite/` |

## Validation and images

The [machine-readable validation record](audit/settings-suite/validation.json)
contains **24 passing checks**, including static validation, bar modes, settings
persistence, both settings UIs, Hyprland integration, compositor safety,
shortcut backups/Lua compatibility, display confirmation, Wi-Fi/audio, Quick
Control, launcher, spacing, speed test and bar-surface regressions.

Final targeted runs additionally verify:

- 14 shared-suite QML cases plus save/reload in a fresh engine.
- 19 Hyprland QML cases.
- 28 material/backend cases, including execution of generated Lua against local
  stub APIs.
- No binding-loop, recursive-rearrange, undefined-property or assignment errors
  in the two final UI runs. Static validation reports zero issues.

The sidebar hover regression checks icon/text geometry, all four row edges,
the content area, search, scrolling without mouse movement, focus moving to
another window, and expanded/collapsed sidebars. The previous 38px delegate
used Basic's 12px padding on each side, leaving a 14px content height for 27px
icons. Explicit 5px vertical padding and content-driven row height keep the
content inside its hit area. A single passive hover handler on the scrolling
viewport resolves the current row from pointer position and scroll offset;
delegate hover no longer stays latched after scrolling. Hover exits clear
immediately, while selection and keyboard focus remain independent.

Tests use isolated settings and an offscreen Qt/software backend on installed
Quickshell 0.3.2 (Omarchy). Expected offscreen warnings concern unavailable
desktop services, IPC sockets and window masks. They are not native-device or
native-blur verification. Quickshell 0.3.1 remains the source baseline.

| Image | Provenance |
| --- | --- |
| [Reported appearance before](audit/settings-suite/before-reported-appearance.png) | The user's supplied screenshot of the UI issue. |
| [Appearance after](audit/settings-suite/appearance-after-offscreen.png) | Actual QML capture, offscreen; independent RAGE Dark selected in the test. |
| [Bar & Dock after](audit/settings-suite/rusticq-after-offscreen.png) | Actual QML capture with the real preview/settings bindings. |
| [Hyprland after](audit/settings-suite/hyprland-after-offscreen.png) | Actual QML capture with fixture compositor data. |

These captures show layout and controls. Test capability flags are explicitly
set for material coverage; the captures do **not** prove desktop backdrop blur.

## Environment limits

The current compositor adapter supports its audited Hyprland 0.55–0.57 named
Lua rule API. Other versions, missing capabilities, disabled global blur and
unsupported compositors use the readable fallback. Existing Niri configuration
support is retained; this redesign does not add a Niri backdrop-blur protocol.
Existing compositor configuration errors may also prevent a safe rule update.

Direct Hyprland socket access from this tool environment is restricted. Actual
wallpaper/application blur, hardware changes, compositor decoration behavior,
monitor hotplug and a native Quickshell 0.3.1 session still need desktop
verification. No before/after desktop-blur claim is made from offscreen images.
Independent painting for notifications/popovers is supported, but surfaces that
share an existing Wayland namespace retain that namespace's blur granularity.
