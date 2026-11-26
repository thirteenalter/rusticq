# Launcher Studio and Detached Floating Search

Unreleased incremental Beta 4 feature; no release version change.

- Preserve Compact/Clean Compact Hover and add Spotlight, Raycast, Launchpad,
  Fluent, Minimal, Classic Menu, Overview, Compact Command and Detached Floating
  Search through the existing launcherLayoutMode selector.
- Extract one shared search/provider controller; retain safe desktop-entry
  execution, restricted calculator, providers, pins and application usage.
- Replace unconditional fullscreen dimming with a bounded launcher plus independent
  optional None/Dim/Blur/Dim and Blur/Focus backdrop. Use real scoped native blur.
- Add RAGE-aware material/geometry/visibility, style gallery with actual previews,
  live settings, migration/persistence, per-style positioning and shared motion.
- Detached uses two independent materials, a transparent gap, stable input anchor,
  dynamic list/grid/adaptive results, independent customization and targeted reset.
- Correct provider-binding timing, stale action dismissal, auto-geometry reload,
  Overview sidebar sizing, missing icons and native resize-animation artifacts.
- Add offline/QML/native regressions, actual screenshots and pixel blur/gap proof.

See [implementation report and validation](../docs/LAUNCHER-STUDIO.md).
