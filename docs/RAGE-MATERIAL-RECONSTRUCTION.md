# RAGE material reconstruction and native palette isolation

Implemented in the working repository, without changing the release version or
the installed shell copy. The Launcher Studio update builds on this foundation.

## Confirmed root causes

1. Hyprland 0.56.2 returns `{"bool":true}` for `decoration:blur:enabled`.
   The adapter read only `int`, reported blur disabled, and forced every primary
   surface to the 86% no-blur fallback. Modern booleans and legacy integer 0/1
   are now validated explicitly. Global compositor settings remain untouched.
2. This checkout had no Exclusive provider. `glassTint` mixed the selected
   Gruvbox/Aether background with its accent; foreground, borders and reflections
   also used those external colors. A single Theme resolver now selects exactly
   one provider: Gruvbox, Aether or RAGE Native.
3. A bright gradient covered the top 42% and a dark gradient covered the bottom
   22% of each material. Together with high alpha, these produced a thick tinted
   plate. Lighting is now a 2.5% wash fading by 20% height, a one-pixel top glint
   and two-pixel bounded contact shading. The parent owns the only outline.
4. Standalone connectivity cards repeated their own fill/border over the popup.
   These are transparent in glass mode. Nested content uses 3–6.5% overlays,
   without additional backdrop passes.
5. Small muted text was insufficient on a bright background. Shared GlassLabel
   adds local glyph contrast while keeping text opaque, and contentMuted uses
   the secondary foreground on glass. Geometry and text metrics remain intact.
   Native Qt Controls receive the same central palette rather than platform
   theme colors.

Native PanelWindow canvases were already transparent; an opaque parent was not
the cause for widgets or bar popups. Floating settings windows intentionally
own one window material and keep compositor-owned decorations.

## Provider, material and geometry

**Appearance → Glassmorphism → Theme provider → RAGE Exclusive** chooses the
native provider independently of the glass toggle. Its default Obsidian palette
uses `#19191c`, `#f5f5f7`, `#c7c7cc`, `#98989f`, a silver accent and white edges.
Pearl, Pure Crystal and Graphite Frost use their own native constants. Semantic
warning/error/success/info colors remain meaningful. External palette updates
can update their cache, but cannot alter any effective native token.

Adaptive is retained for existing configurations and restores the saved external
source. Selecting Exclusive never rewrites colorSource or the Gruvbox accent.
Disabling glass on the bar or globally does not deselect an explicit native
provider. Select Adaptive to restore the external theme. Base background/text
remain opaque even if an external TOML entry contains alpha.

Frosted/Crystal/Tinted now default to .44/.24/.50 material alpha. Popup alpha has
a .50 readability floor, window alpha .56; a real unavailable-blur backend still
uses .86 fallback. Saved custom alpha is preserved. Presets no longer overwrite
corner geometry, provider, native palette or decorative visibility.

All bar background/outline controls, independent radii, capsules, performance
mode, low-memory behavior and opaque lock backing are retained. Hidden material
layers unload their lighting; zero-width outlines suppress the edge glint.
No authentication/controller logic, framebuffer capture or shader was added.

## Actual compositor and blur evidence

Tested on **Hyprland 0.56.2 / Omarchy, Quickshell 0.3.2**, one 1920×1080 output
at scale 1. Quickshell 0.3.1 remains the API baseline, but was not installed for
an actual 0.3.1 runtime run. The adapter still gates audited Hyprland Lua
versions/capabilities; unknown/legacy backends and Niri use the readable fallback.

Native layer rules use alpha-aware `ignore_alpha=0.02`, allowing Crystal alpha
while excluding fully transparent regions. `xray=false` allows a layer's blur
to sample the application behind it. These are documented
[Hyprland 0.56 layer effects](https://wiki.hypr.land/0.56.0/configuring/basics/window-rules/#layer-rules).
Floating windows use window rules; no per-QML-item backdrop API is claimed.
Blur strength remains compositor-owned. RAGE never changes global blur size,
passes, enablement, compositor files, Omarchy defaults or unrelated applications.

Captures used real native components over a temporary patterned application,
with privacy-safe network/media/weather fixtures. A unique session-only test
rule was disabled afterward; the installed shell and wallpaper were unchanged.
Production matching/safety is separately covered by backend/source tests.

With identical material alpha, a checkerboard remained sharp when fixture blur
was disabled and softened when enabled. Grayscale standard deviation in a blank
notes region fell from **39.67 to 2.09**; the popup region fell from **37.00 to
0.65**. Outside both surfaces it stayed **73.65** in both captures. This is
evidence of compositor blur rather than a darker Rectangle. Exact regions and
measurements are in [blur-proof.json](audit/rage-material/blur-proof.json).

## Actual captures

The very top 40-pixel bar belongs to the pre-existing installed shell; the new
fixture bar is the Separated row below it. The installed bar's warm colors are
not part of the tested native provider. Colored application icons retain their
original artwork. Wallpaper colors naturally show through native glass without
changing its internal palette.

| Test background | Before | After |
| --- | --- | --- |
| Detailed monochrome | [Capture](audit/rage-material/before/monochrome.png) | [Capture](audit/rage-material/after/monochrome.png) |
| Bright white | [Capture](audit/rage-material/before/white.png) | [Capture](audit/rage-material/after/white.png) |
| Color stripes/details | [Capture](audit/rage-material/before/color.png) | [Capture](audit/rage-material/after/color.png) |
| Checkerboard | [Capture](audit/rage-material/before/grid.png) | [Capture](audit/rage-material/after/grid.png) |
| Text application | [Capture](audit/rage-material/before/text.png) | [Capture](audit/rage-material/after/text.png) |

Additional views: [Settings](audit/rage-material/after/settings.png),
[Quick Control](audit/rage-material/after/quick-control.png),
[Launcher](audit/rage-material/after/launcher.png),
[same-alpha blur disabled](audit/rage-material/blur-control/grid.png).
The launcher capture records the material phase before Launcher Studio changes.

## Files and validation

Core changes: Theme.qml, SettingsStore.qml, GlassSurface/GlassHighlight,
GlassLabel/ControlPalette, connectivity cards, desktop widgets, shared labels,
native Qt Controls and rusticq-glass.py. See the precise material-phase
[source manifest](audit/rage-material/source-files.json). Tests, example JSON,
README, FEATURES and the RAGE guide are updated separately.

- Native provider regression: every effective semantic color, all four native
  palettes and three styles, glass on/off, extreme red/green/yellow Aether and
  Gruvbox accent changes, actual temporary Aether file updates and saved reload.
- Material UI: real provider buttons, glass toggle/presets, custom values,
  opacity preview/commit, low-memory resource release, malformed JSON/migration.
- Bar regression: all 64 visibility combinations, five modes/four edges and two
  simulated monitor geometries, custom geometry and save/reload.
- Connectivity/weather/clock, Settings, portable configuration, compositor
  safety/UI, lock structure/design, menu/QR and motion suites were executed.
- Real Wayland keyboard input through wtype: Wi-Fi/Bluetooth reopen cycles,
  animation on/off and panel handoff passed. Native motion/window lifecycle,
  launcher/Quick Control/AI, toast and OSD tests passed.
- A motion test exposed a test-order race: progress completed before its Binding
  targets settled. It now observes actual intermediate frames and waits for exact
  final target values; production motion behavior was not changed by that fix.

See the [companion validation JSON](audit/rage-material/validation.json) for commands/results. Offscreen fixtures can
emit expected IPC/DBus-unavailable warnings; these do not prove hardware actions.
Native captures had no QML syntax errors, undefined properties or binding loops.
An isolated app-usage-file/Hyprland workspace-tracking warning was observed in
the fixture. No GPU overhead benchmark is claimed.

## Remaining manual verification

- Try the other native palettes on personal wallpapers; pixel comparisons used
  Obsidian, while palette independence was automated for all four.
- Exercise physical multi-monitor clicks, monitor hotplug and fractional scale;
  native capture had one scale-1 monitor, with multi-monitor geometry simulated.
- Verify real device operations and authentication in the installed session;
  visual tests do not change networks, pair devices, request credentials or lock.
- On unsupported compositors, expect refined translucent/opaque fallback rather
  than native blur. Extreme custom alpha can still reduce text contrast.
- Load/install the revised repository to use the changes in the installed shell;
  the pre-existing installed copy was deliberately not replaced during testing.
