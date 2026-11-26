# RAGE material reconstruction

- Fix Hyprland typed-boolean detection that incorrectly forced 86% fallback.
- Resolve exactly one Gruvbox, Aether or independent RAGE Native provider.
  Preserve external preferences and all four native palette choices.
- Rebuild neutral materials, thin lighting, nested overlays and local text
  contrast; remove repeated standalone connectivity fills/outlines.
- Preserve geometry and visibility when changing material presets; native solid
  surfaces remain native when glass is disabled.
- Validate real compositor blur with paired same-alpha native captures and
  extreme runtime palette changes. See the material reconstruction report.
- No release bump, compositor configuration overwrite or authentication change.
