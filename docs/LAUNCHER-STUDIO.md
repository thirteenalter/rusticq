# RusticQ Launcher Studio

Launcher Studio adds nine modern presentations to the two existing launcher
layouts. All eleven use one application index, search controller and execution
path. It is an incremental Beta 4 update; the release version and Quickshell
0.3.1 API baseline are unchanged.

Latest follow-up: [launcher/dock motion fix](LAUNCHER-DOCK-MOTION.md) adds stable
transparent canvases and a warm launcher cache. Earlier captures below record the
initial Studio implementation; the follow-up has its own native measurements.

## Enable and customize

Open **Settings → App Launcher → Launcher Studio**, select a gallery card, then
use **Test Launcher**. The preview uses the actual frontend and installed icons,
without starting another controller or provider process. The button opens the
single launcher session on the settings monitor.

Fresh configurations use **Spotlight**. Existing Compact/Clean Compact Hover
preferences and saved dimensions are retained. Old nonempty settings without a
layout selector migrate to Compact with the original 605-pixel maximum height
and 56-pixel rows; an empty/missing configuration uses modern defaults.

**Use recommended style geometry** chooses geometry appropriate to each modern
style. Turn it off for custom shared dimensions. Input height/font, row/icon
sizes, columns, padding, spacing, branding, categories, favorites, recents,
hints and detail preview have relevant controls. Width/height remain clamped to
the selected output. Style changes preserve the current query and editor focus.

Position supports center, upper/lower center, four corners, Follow bar and
normalized custom coordinates, with offsets. Classic Menu uses the real bar
trigger rectangle when clicked from the bar, for all four bar edges. A keyboard,
IPC, dock or Settings opening without that anchor uses a clamped monitor-relative
bar-edge fallback (60-pixel top/bottom or 80-pixel side inset).

## Layout coverage and actual screenshots

These are native Wayland captures of the production components, not mockups.
The fixture uses real installed application entries and icons over a controlled
detailed background. Both empty and populated states were captured for every
style. They use native RAGE Obsidian; original icon artwork stays colored.

| Style / stored key | Presentation | Default backdrop | Empty | Search |
| --- | --- | --- | --- | --- |
| Legacy Compact / `compact` | Branding, frequent/pinned apps, classic list | Dim | [Capture](audit/launcher-studio/compact-empty.png) | [Capture](audit/launcher-studio/compact-populated.png) |
| Legacy Clean Compact Hover / `clean-hover` | Small header, hover-revealed list, delayed hover collapse | Dim | [Capture](audit/launcher-studio/clean-hover-empty.png) | [Capture](audit/launcher-studio/clean-hover-populated.png) |
| Spotlight / `spotlight` | 680×68 search-only opening, expanding list, optional detail | None | [Capture](audit/launcher-studio/spotlight-empty.png) | [Capture](audit/launcher-studio/spotlight-populated.png) |
| Raycast / `raycast` | 760-pixel command palette, categories, provider actions, session action history, footer | None | [Capture](audit/launcher-studio/raycast-empty.png) | [Capture](audit/launcher-studio/raycast-populated.png) |
| Launchpad / `launchpad` | Large scrolling icon grid, names, search and categories | Blur | [Capture](audit/launcher-studio/launchpad-empty.png) | [Capture](audit/launcher-studio/launchpad-populated.png) |
| Fluent / `fluent` | Pinned/frequent grid, recent apps and All apps list | None | [Capture](audit/launcher-studio/fluent-empty.png) | [Capture](audit/launcher-studio/fluent-populated.png) |
| Minimal / `minimal` | 520-pixel lightweight search and plain list | None | [Capture](audit/launcher-studio/minimal-empty.png) | [Capture](audit/launcher-studio/minimal-populated.png) |
| Classic Menu / `classic` | Bar-relative panel with category sidebar and favorites/recents | None | [Capture](audit/launcher-studio/classic-empty.png) | [Capture](audit/launcher-studio/classic-populated.png) |
| Overview / `overview` | Large grid plus bounded favorites/recent sidebar | Dim and Blur | [Capture](audit/launcher-studio/overview-empty.png) | [Capture](audit/launcher-studio/overview-populated.png) |
| Compact Command / `command` | 500×46 search-only opening, compact list/calculator | None | [Capture](audit/launcher-studio/command-empty.png) | [Capture](audit/launcher-studio/command-populated.png) |
| Detached Floating Search / `detached` | Independent 660×64 input and separate results surface | None | [Capture](audit/launcher-studio/detached-empty.png) | [Capture](audit/launcher-studio/detached-populated.png) |

The user-supplied image records the previous appearance; it is not a
same-background automated comparison.
For material-phase before/after comparisons, see the separate
[RAGE reconstruction report](RAGE-MATERIAL-RECONSTRUCTION.md).

## Detached Floating Search

Only the focused search input appears initially. Typing shows a separate result
surface, with a genuinely transparent gap, default 10 pixels. Clearing the query
animates the results out and restores the input-only state. There is no visible
parent plate. The input stays at its monitor-relative anchor as results change.

Results offer List, Grid and Adaptive. Adaptive uses the configured app layout;
files, notes, settings and other tool providers use lists, and calculator uses a
compact dedicated result. Columns adapt to available width; long results scroll
within the maximum height. Maximum returned app rows is configurable separately.

Input and results each have glass, opacity inheritance/override, background,
outline, radius, highlights and shadow intensity. Their controls do not change
the other surface. Independent geometry includes result width/alignment, gap,
up/down/automatic expansion, input font/placeholder/icon/hint and optional empty
results. The default hides empty results. Reset Detached Launcher Appearance
changes only its dedicated fields.

Actual states: [one match](audit/launcher-studio/detached-one.png),
[calculator](audit/launcher-studio/detached-calculator.png),
[no matches](audit/launcher-studio/detached-none.png),
[cleared](audit/launcher-studio/detached-cleared.png),
[independent opacity](audit/launcher-studio/detached-independent-materials.png),
[list](audit/launcher-studio/detached-list.png),
[background/outline off](audit/launcher-studio/detached-naked.png).

## Shared search and interaction

Application discovery uses native DesktopEntries. Existing bounded fuzzy
ranking, pin/usage ordering, desktop-entry execution and usage persistence are
preserved. Right-click an application for Open/Pin/Unpin. Up/Down select results;
grid navigation also supports Left/Right after entering result navigation.
Clicking the editor returns arrows to text editing. Enter activates; calculator
Enter copies via the existing wl-copy path. Escape closes a context menu first,
then the launcher. Tab reaches actions; accessible controls retain focus feedback.

The existing restricted calculator and prefixes remain available in every style:
`:files`, `:folders`, `:notes`, `:settings`, `:windows`, `:workspaces`, `:emoji`,
`:wallpaper`, `:color`, `:ocr`. No arbitrary shell evaluation is introduced.
Non-app providers do not become application grids. Calculator/tool debounce,
response-query checks and reruns after an in-flight query changes are shared.
A zero-delay controller update lets QML provider bindings settle before arming
those existing debounces. Changing queries cancels delayed action dismissal.

Recent applications and pins persist in the existing app usage mechanism.
Raycast's recent provider actions are bounded to eight, session-only, and never
write file paths, note contents or provider payloads into app-usage.json.

## Backdrop, compositor and RAGE

Desktop backdrop is independent of launcher material. Auto follows the table;
explicit **None / Dim / Blur / Dim and Blur / Focus** overrides every style.
None creates no fullscreen window, dim, tint or blur carrier. A bounded transparent
PanelWindow owns the launcher, with a union input region for Detached's boxes.
HyprlandFocusGrab handles outside clicks as one logical session; opening retains
exclusive-then-on-demand keyboard focus without a fullscreen input catcher.

Optional fullscreen backdrop is a separate keyboard-inert Top-layer window,
below the Overlay-layer launcher. Dim uses the actual configured alpha. Blur
uses a 1/255-alpha carrier only with an active native backend. Unsupported blur
uses readable dim fallback. Focus increases distraction-reducing dimming. No
fake strength slider is exposed: the audited backend has no independent per-window
blur strength. Global compositor blur options are never changed.

The existing RAGE adapter owns six named session rules: shared layers, bar,
normal windows, bounded launcher blur, explicit launcher-backdrop blur, and
launcher presentation. The two launcher blur rules have exact namespace matches.
The presentation rule suppresses a second compositor animation only for these
two namespaces: actual captures exposed a trailing strip during native resize
animation, which vanished when QML's SurfaceMotion became the sole animation
owner. Presentation stays independent of glass and is disabled on owner-guarded
service cleanup. Rule updates include rollback; no configuration files, restart,
sudo, global animation/blur options or unrelated rules are changed.

Audited Lua capabilities on Hyprland 0.55–0.57 are version/function gated; native
verification here used **Hyprland 0.56.2 / Omarchy and Quickshell 0.3.2**.
The `ignore_alpha`/`no_anim` APIs follow the
[versioned Hyprland documentation](https://wiki.hypr.land/0.56.0/configuring/basics/window-rules/#layer-rules).
Legacy/unknown Hyprland, Niri and unavailable IPC use existing fallback. Native
0.3.1 was not installed; its documented APIs remain the compatibility baseline.

Exclusive always uses native RAGE semantic tokens, including solid launchers
and each Detached box. Adaptive keeps Gruvbox/Aether. Background, outline,
material and corner settings are independent. Standard application artwork is
not recolored. Missing installed icon files use a neutral fallback, cached once
per controller to avoid repeated failed loads.

## Architecture and changed files

- **Backend:** new `components/LauncherController.qml` extracts the existing
  MiniLauncher search/providers safely. `services/AppUsage.qml` adds bounded
  nonpersistent provider action history.
- **Frontend:** new `LauncherView.qml`, `LauncherResults.qml`, `LauncherAppIcon.qml`;
  one persistent editor plus lazy list/grid/detail views. MiniLauncher remains a
  compatible facade exposing existing methods and aliases.
- **Presentation:** `LauncherOverlay.qml` is bounded; new `LauncherMaterial.qml`
  resolves RAGE preferences for the main surface or each Detached part.
  `config/LauncherStyle.qml` centralizes style metadata and clamped placement,
  and is registered in `config/qmldir`. SurfaceMotion accepts an optional animate
  gate and travel distance while retaining existing defaults for all other owners.
- **State/persistence:** `SettingsStore.qml` validates and migrates the existing
  layout selector and appearance fields, saves via the existing FileView/snapshot,
  and applies visual-only external edits without shell reload. Store.qml owns the
  transient trigger anchor and backend status. Bar.qml/BarZone.qml forward the
  real trigger rectangle; spacing/exclusive zones are unchanged.
- **Settings:** SettingsLauncherPage.qml uses the actual LauncherStylePreview and
  new LauncherSettingRow editors with slider preview/commit. It retains the
  existing Settings window/navigation. The schema is documented in the
  [settings reference](LAUNCHER-STUDIO-SCHEMA.md) and user-settings.example.json.
- **Compositor:** GlassService.qml and rusticq-glass.py extend existing owned
  session rules. Theme.qml remains the only palette/material token source; its
  shared shadow curve now responds across the full intensity range.
- **Regression/docs:** new `test_launcher_studio.py`, `test_launcher_studio_ui.py`
  and `capture_launcher_studio.py`; existing provider/fuzzy/layout/updater,
  settings, lock-design and material tests follow the extracted architecture.
  Static-validation CI includes the offline contracts. README, FEATURES,
  example settings, this guide/schema and changelog are updated.

## Validation and measured results

The [machine-readable report](audit/launcher-studio/validation.json) records the
commands and results. Static validation is separate from actual QML and Wayland
runs. No hardware action, app execution, authentication or lock was triggered.

- Launcher UI: 10 actual QtTest scenarios plus initialization, **11 passed, 0 failed**;
  all eleven styles keep the same controller/editor, use app search, and retain
  usable grid width. Keyboard grid navigation, fake safe launch, pin/usage,
  provider files/notes/settings/calculator and stale queries passed.
- Detached tests cover empty state, gap, independent colors/alpha/radii, native
  palette isolation, solid/glass toggles, resource release, result alignment and
  upward expansion. Geometry covers eleven styles/four bar edges/three simulated
  output sizes. Low-memory and animations-off changes are immediate.
- Restart verification compares persisted launcher fields, then tests five fresh,
  legacy and malformed-schema configurations plus broken JSON. Legacy geometry and modern automatic
  geometry survive; actual external FileView edits retain query, editor and focus
  without a shell reload; reset does not change unrelated preferences.
- Offline Launcher Studio contracts, original launcher provider/fuzzy/dock/updater
  regressions, static QML, bar modes and material/compositor safety tests passed.
  RAGE provider regression validates 38 tokens across four palettes/three materials,
  glass on/off and extreme watched external palette updates.
- **39 native screenshots** cover both states of eleven styles, Detached's full
  state sequence, five backdrops and Spotlight over a real normal text application.
  wtype reached the focused production editor and Escape dismissed it; controller
  and editor object identity stayed unchanged across captures.
- Native pixel comparison finds no changed desktop region outside None-mode
  windows, allowing one pixel for compositor sampling at their boundary. The
  Detached gap is pixel-identical to the closed fixture background. With identical
  alpha, blank-region luminance deviation drops from **18.56 without blur to
  6.15 with blur**. See [pixel-proof.json](audit/launcher-studio/pixel-proof.json).
- Related native bar/recovery and motion/window lifecycle suites passed. Offscreen
  Wi-Fi/Bluetooth search, weather fallback, Settings, portable config, cloud mocks,
  lock security/design, bar surface matrix and compositor suites passed.

Original failures were addressed: source-contract tests referenced the old
monolithic MiniLauncher; a migration loop reset automatic geometry; immediate
provider dispatch could read stale derived bindings; a flexible Overview sidebar
consumed grid width; compositor resize animation left a transient strip. Their
regressions are now checked. An initial native bar test was blocked by sandboxed
Wayland access, then passed with authorized session access.

## Supplemental historical probes

The active CI/provider suites also pass: Beta 1 feature batch (10), doctor guard
(7), Beta 1 (11), Beta 3 (13) and versioning (15). Production note-provider tests
now use the same isolated notes module as their fixture; the dynamic import had
previously bypassed it. Installer syntax and a full source archive build passed
without a release-version change or including personal user-settings.json.

Four exploratory historical scripts were not green. They are outside the active
validation matrix and their original files were left unchanged:

| Historical script | Actual outcome |
| --- | --- |
| `test_rc3.py` | After adapting its old launcher lookup, stopped on a literal 690-pixel Quick Control limit; HEAD already uses 780 and monitor clamping. |
| `test_rc5_visual_patch.py` | After adapting its old launcher lookup, stopped on a removed explicit `widgetLoader.item.advancedOpen` hook; the popup already follows content implicitHeight in HEAD. |
| `test_alpha4.py` | Requires an old native dock toplevel model; HEAD already uses the guarded running-app helper covered by the current dock tests. |
| `test_rc5_runtime_repair.py` | Did not execute: optional Python `fontTools` is unavailable. No dependency was installed for this historical test. |

These outcomes are included separately in the validation JSON; they are not
counted as passing suites or evidence of runtime verification.

## Performance, limitations and manual checks

No duplicate index/service, polling, framebuffer capture, continuous shader or
per-icon blur is used. Hidden layouts/details are lazy. Low-memory/performance
mode removes expensive effects and native blur while retaining preferences.
All launcher animations use existing Theme durations/SurfaceMotion; no second
motion engine is introduced. CPU/GPU overhead has not been benchmarked.

- Native testing used one 1920×1080 scale-1 output. Check physical multiple outputs,
  fractional scale, monitor hotplug, and all four actual bar trigger placements.
- Outside dismissal uses the existing Hyprland focus-grab protocol. Other compositor
  focus/outside-click semantics have not been runtime-verified. A Top-layer optional
  backdrop can be occluded by a compositor-owned fullscreen application; the bounded
  Overlay launcher remains above it.
- Genuine detached blur requires alpha-aware native blur. Unsupported compositors
  use refined translucent/opaque fallback; there is no invented per-item blur API.
- The captured normal application is a controlled Qt window containing known text.
  Color/structure backgrounds are native fixtures, not a replacement wallpaper.
  Screenshots do not claim the whole installed shell was deployed or benchmarked.
- Missing external desktop-entry icon files can emit one load warning before the
  cached fallback. No QML type/reference/binding-loop failures occurred in the final
  native run. No application folders or fake workspace previews are advertised.
- The pre-existing installed shell copy was not overwritten or restarted. The
  implementation and regression tests are in this repository.

Manual sequence: open Spotlight with None over a detailed wallpaper/application;
verify immediate typing and unchanged desktop; try every style, category, pin,
provider and keyboard action; then open Detached empty, type one/many/no matches,
calculator, clear, click inside either box, click the gap/outside and reopen.
Change each box's opacity/radius/background/outline independently. Verify its input
anchor stays fixed, preferences survive restart, and Quick Control remains styled
independently. Repeat on another monitor and at fractional scale.
