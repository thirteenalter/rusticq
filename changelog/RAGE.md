# RAGE — Global Adaptive Glassmorphism and Independent Bar Surfaces

Date: 2026-11-24

Source feature update for Beta 4; no release/version change.

- Add opt-in RUSTIQ ADAPTIVE GLASS ENGINE, shared semantic tokens and reusable
  GlassSurface/GlassHighlight/GlassPreview components. Preserve the opaque
  Gruvbox/Aether palette and live palette synchronization.
- Add validated, persistent glass controls to existing Appearance Settings,
  including live preview, presets, reset, sliders with separate preview/commit,
  compositor support and performance status. Older settings remain standard.
- Apply shared materials across active shell windows, lazy panels, controls,
  desktop widgets and auth views. Keep an opaque session-lock backing and the
  original authentication controllers.
- Add independent bar container, segment and module background/outline controls,
  synchronized Bar/Appearance editors and a preview using the real BarSurface.
  Add Original, Glass Rail, Borderless Glass, Floating Segments, Outline Only
  and Naked Bar presets, per-bar glass, rail fill, opacity and geometry controls.
- Correct the Separated full-width frame: a zero-width native rail border is
  no longer promoted into a glass border. Hidden decoration cannot retain an
  edge highlight or contact shading. Keep Professional's full rail and square
  default outer geometry. Glass remains available in every bar mode.
- Add version/capability-gated Hyprland session rules with exact RusticQ matches,
  alpha-aware blur and a separate bar rule preserving popup blur. Generation
  ownership prevents an old shell destructor disabling a replacement instance.
  Never change global blur, compositor defaults or config files.
- Add offline, offscreen QML and opt-in native Wayland regression suites and a
  complete surface audit. Update older assertions for retained popup content,
  current monitor controls, glass wrappers and immediate QR cleanup. Font glyph
  checks can use installed fontconfig when Python fontTools is absent.
- Move confirmation Escape handlers onto actual visual Items, avoiding invalid
  Keys attachments to FloatingWindow wrappers during startup.

Details, limitations, test results and manual checks: [docs/RAGE.md](../docs/RAGE.md).
