# RusticQ Hyprland Settings

RusticQ now has a separate native configuration studio, with its own floating
window, navigation, search, theme and lazy lifecycle. RusticQ Settings can stay
open alongside it. This implementation uses Quickshell/QML and the repository's
existing Python configuration gateway; it adds no Python or Qt dependencies.
The minimum remains Quickshell 0.3.1 / Qt 6.

## Open the studio

- Search **RusticQ Hyprland Settings**, **hyprland**, or **pengaturan hyprland** in
  any RusticQ launcher style. Favorites and recent applications work normally.
- Shell menu → **Hyprland Settings**.
- `rusticq hypr-settings` in an installation using the updated installer.
- Development tree: `python3 scripts/rusticq-cli.py hypr-settings`.
- IPC: `qs ipc -p /path/to/rusticq call rusticq dispatch hypr-settings`.
- Assign the **RusticQ Hyprland Settings** action in the existing shortcut manager.

The normal RusticQ shell must be running. These entry points open its single
studio toplevel; they do not launch another shell. Repeated activation raises
the same window. The installer installs
`desktop/org.rusticq.HyprlandSettings.desktop` and its icon when explicitly run.
Source development does not install files into the user's application directory.
The old `settings-compositor` IPC action opens the new studio in a Hyprland
session. The Compositor page provides an opening shortcut; Niri retains its
existing compositor editor and backend.

## Implemented interface

- A 1100 × 760 default window, 800 × 560 minimum, remembered normal dimensions,
  native move/resize/minimize/maximize/close, and one lazy window owner.
- macOS-inspired grouped controls, a 250 px sidebar, colorful category icons,
  independent sidebar/content scrolling, and collapsible navigation.
- Follow RusticQ, neutral dark, and neutral light palettes. Existing display
  and shortcut views receive a scoped palette without changing their appearance
  elsewhere. Follow mode honors the current Theme provider, including RAGE.
- Search across all 21 categories and the scalar schema, including configuration
  identifiers and aliases such as `touchpad` and `bind`. Results navigate to and
  briefly highlight controls. Ctrl+F opens search; Ctrl+R refreshes;
  Ctrl+Enter reviews a draft; Ctrl+W closes with a draft confirmation.
- Overview: version/build, format, paths, session detection, active displays,
  workspace, window count, reported config errors, reload and folder opening.
- 75 runtime-probed scalar options for appearance, effects, animations, layouts,
  keyboard, mouse, trackpad, gestures, performance and miscellaneous behavior.
  Native `descriptions` supplies version-specific numeric limits and factory
  defaults. When a default cannot be established, Reset removes the RusticQ
  override rather than inventing a factory value.
  Unknown effective values remain unmeasured. Uniform CSS gaps are normalized;
  gradients and asymmetric gaps are not misrepresented as scalar values.
- Structured managed-entry editors for workspace rules, window rules, layer
  rules, animations/Bézier curves, gestures, startup commands, non-secret
  environment variables and per-device overrides. Entries can be reordered,
  enabled, edited and removed. Window, device and layer pickers use actual
  compositor data. Existing entries remain in their original files.
- Local interactive desktop/layout previews, a draggable Bézier editor and
  animation sample, and a gesture demonstration. These previews never execute
  compositor commands per frame.
- The existing monitor arrangement, mode/refresh and scale controls, including
  drag placement, verified readback, export and the independent 15-second
  Keep/Revert watchdog. The existing shortcut manager retains its searchable
  registry, conflict handling, full backup confirmation and restoration.
- Shared shortcut confirmations now carry the caller identity and parent
  window title, preventing an approval in one settings window from applying
  pending work in another. Navigation waits for an active shortcut operation.
- Read-only configuration browser with static include discovery, line numbers,
  comment highlighting, search and external opening. The managed settings JSON
  editor stages schema-validated data for generation of native configuration.
- Built-in presets (macOS-inspired, Minimal, Glassmorphism, Performance,
  Balanced, plus Default Hyprland when the compositor reports factory defaults),
  private custom presets, managed JSON import/export,
  manual snapshots, automatic pre-apply snapshots, guarded restore and managed
  override reset. Presets never change shortcuts, displays or startup commands.

## Configuration ownership and transactions

`scripts/rusticq-compositor-config.py` remains the entry point. Its `studio-*`
actions delegate to `hypr_settings_studio.py`, using the same atomic writer and
`editor.lock` as the old compositor editor. The original four-section API and
Niri support remain intact.

The studio distinguishes effective runtime values, the existing user/include
configuration, and its own `rusticq-studio.lua` or `rusticq-studio.conf` fragment.
Persistent Apply adds only an owned source block to the detected entrypoint and
writes that fragment. It preserves surrounding comments and custom config.
Custom `--config` paths are detected from the active Hyprland process command
line. Literal `source`, `dofile` and `require` includes are followed without
executing Lua. Symlinked, foreign-owned, malformed or unrecognized writable
targets fail closed.

Changing controls updates a local draft. Review validates supported options,
ranges and record fields and shows the exact generated configuration diff.
Apply requires that preview's fingerprint, checks included-file hashes again
under the shared lock, snapshots the original bytes, writes atomically, reloads,
checks compositor errors and verifies scalar effective values where measurable.
Failure restores both original files and checks recovery. Interactive Restore
shows a new diff against the selected historical snapshot, preserves current
unmanaged lines/includes, checks its fingerprint again and backs up the current
managed state before writing. A stale restore preview is rejected. The strict
CLI rollback without a preview token additionally requires an unchanged complete
snapshot after-state. File watchers invalidate previews on external changes.
Reload preserves unsaved local drafts.

Snapshots and custom presets are stored privately below
`$XDG_STATE_HOME/rusticq/compositor-config/` (default `~/.local/state/…`).
`studio-history/<snapshot>/manifest.json` includes base64 copies of the two
original files for recovery from a terminal. An absent fragment is recorded and
removed on rollback. Backups may contain the user's original configuration, so
they must remain private. Credentials are rejected in the environment-variable
editor; process environment values are never imported.

## Persisted UI preferences

These keys are validated and serialized through `config/SettingsStore.qml`,
with backward-compatible defaults, a reset function and live appearance updates:

| Key | Default | Validation |
| --- | --- | --- |
| `hyprSettingsWidth` | `1100` | finite integer, 800–2400 |
| `hyprSettingsHeight` | `760` | finite integer, 560–1800 |
| `hyprSettingsTheme` | `"dark"` | `follow`, `dark`, `light` |
| `hyprSettingsGlass` | `false` | boolean |
| `hyprSettingsShowUnsupported` | `true` | boolean |

Compositor values and commands are not stored in `user-settings.json`.

## Compatibility and remaining limits

The studio is functional for its audited schema, rather than a universal editor
for every possible Hyprland extension. Coverage is explicit:

- The current write gate covers Lua Hyprland 0.55–0.57 and legacy hyprlang
  0.40–0.54. Other versions/formats are read-only until their APIs are audited.
  Each scalar still requires a successful runtime `getoption` probe.
- Window/layer rules and gesture records currently use the audited Lua schema.
  Legacy rules remain read-only instead of mixing incompatible syntaxes.
- Plugin status is read-only. Plugin-specific schemas, automatic compatibility
  inference, installation and load/unload controls are not implemented.
- The existing display backend exposes position, mode/refresh and scale.
  Rotation, mirroring, output disabling, HDR, bit-depth and per-output VRR are
  not added here. Global VRR appears only when its runtime option is available.
  Persistent display snippets still use the existing explicit export workflow.
- The existing shortcut manager's supported edit/remap/action workflows are
  reused; this change does not add arbitrary dispatcher/command editing, submap
  authoring or shortcut import/export.
- Unmanaged native config stays read-only inside the studio. The editable raw
  representation is managed settings JSON, not unrestricted executable Lua.
  Dynamic Lua include paths cannot be resolved by the static file browser.
- Layout-specific support is currently Dwindle/Master. Plugin/scrolling layout
  option schemas require a separate audited extension.
- Runtime changes outside Apply are limited to the existing monitor workflow.
  Appearance/layout/animation previews run locally; optional live compositor
  preview is not implemented.
- Native compositor decorations are retained. Quickshell 0.3.1 shares the shell
  application identity across its windows, so the studio has its own title and
  launcher/desktop icon but no independently assigned Wayland app ID.
- The optional sidebar treatment is a readable translucent fallback over the
  window background. It does not claim compositor backdrop blur. No Hyprland
  rules or user compositor settings are silently changed for this effect.

API references used for the audited generation:
[Hyprland config options](https://wiki.hypr.land/configuring/core/config-options/),
[devices](https://wiki.hypr.land/configuring/core/devices/),
[environment](https://wiki.hypr.land/configuring/core/environment-variables/),
[0.55 hyprctl protocol source](https://github.com/hyprwm/Hyprland/blob/v0.55.0/src/debug/HyprCtl.cpp),
[Quickshell 0.3.1 FloatingWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/FloatingWindow/).

## Changed source files

Added:

- `modules/hyprsettings/`: window, sidebar, style, reusable controls, schema-driven
  page composition, overview/files/backups pages, record editor and local previews.
- `services/HyprlandConfigService.qml`.
- `scripts/hypr_settings_schema.py`, `scripts/hypr_settings_studio.py`.
- `desktop/org.rusticq.HyprlandSettings.desktop`, `assets/rusticq-hypr-settings.svg`.
- `modules/settings/pages/LegacyCompositorPage.qml` (preserved old editor).
- `tools/test_hypr_settings.py`, `tools/test_hypr_settings_ui.py`,
  `tools/test_hypr_settings_integration.py`.

Integrated through `shell.qml`, `config/Store.qml`, `config/SettingsStore.qml`,
`services/qmldir`, `components/LauncherController.qml`,
`modules/main/ContextMenu.qml`, the Compositor/Shortcuts pages,
`modules/settings/SettingsSection.qml`, `modules/bar/BarMonitors.qml`, the shortcut
confirmation window/helper, the compositor gateway, desktop action catalogue,
CLI, installer, example settings and regression contracts.

## Verification

Backend tests use isolated temporary configuration trees and mocked Hyprland
responses; QML tests execute the actual components through `qs` with the offscreen
platform. They do not write the user's Hyprland configuration. See
`tools/test_hypr_settings.py` and `tools/test_hypr_settings_ui.py` for the executable
coverage of transactions, unsupported/invalid values, rollback, external edits,
legacy/Lua generation, actual slider/toggle/text input, draft/apply, navigation,
search, launcher deduplication, concurrent-window confirmation ownership,
preferences and small-window resizing.

The desktop runtime could not be verified: this environment cannot connect to
the user's Wayland/Hyprland sockets. Offscreen warnings about IPC, window masks
and raising are platform limitations. No claim of live compositor Apply,
monitor switching, real blur or shortcut mutation is made.

The final studio checks passed **39 backend tests**, **18 actual QML tests**
(including QtTest initialization), and **4 launch/installation checks**.
The 19 executed validation scripts and exit codes are recorded in
[the validation report](audit/hypr-settings/validation.json). They include the
required static/bar/settings checks, the old compositor safety/UI tests,
desktop integration, shortcut compatibility/full backups/confirmation, the
display watchdog, Wi-Fi/audio, launcher styles and surface-spacing regressions.

[Offscreen appearance render](audit/hypr-settings/appearance-offscreen.png)
uses isolated fixture values; it is not a screenshot from a live Hyprland session.
