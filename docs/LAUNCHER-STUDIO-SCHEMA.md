# Launcher Studio settings schema

All values persist in the existing `user-settings.json`. `launcherLayoutMode` is the only style selector. No separate launcher preferences file is created. Values below are fresh-install defaults; validated legacy files retain Compact/Clean Hover and their saved dimensions.

| Setting | Default | Validation |
| --- | --- | --- |
| `launcherLayoutMode` | `"spotlight"` | compact / clean-hover / spotlight / raycast / launchpad / fluent / minimal / classic / overview / command / detached |
| `launcherWidth` | `660` | 320–1920 |
| `launcherHeight` | `520` | 120–1200 |
| `launcherIconSize` | `30` | 16–96 |
| `launcherRowHeight` | `48` | 28–96 |
| `launcherFavoriteColumns` | `3` | 2–8 |
| `launcherPosition` | `"auto"` | auto / center / upper-center / lower-center / top-left / top-right / bottom-left / bottom-right / follow-bar / custom |
| `launcherOffsetX` | `0` | -1000–1000 |
| `launcherOffsetY` | `0` | -1000–1000 |
| `launcherCustomX` | `0.5` | 0–1 |
| `launcherCustomY` | `0.2` | 0–1 |
| `launcherBackdropMode` | `"auto"` | auto / none / dim / blur / dim-blur / focus |
| `launcherBackdropOpacity` | `0.25` | 0–0.85 |
| `launcherGlassmorphismEnabled` | `true` | boolean |
| `launcherMaterialMode` | `"inherit"` | inherit / solid |
| `launcherOpacity` | `-1.0` | -1–1 |
| `launcherCornerRadius` | `-1` | -1–48 |
| `launcherBackgroundEnabled` | `true` | boolean |
| `launcherOutlineEnabled` | `true` | boolean |
| `launcherHighlightsEnabled` | `true` | boolean |
| `launcherShowBranding` | `false` | boolean |
| `launcherShowCategories` | `true` | boolean |
| `launcherShowFavorites` | `true` | boolean |
| `launcherShowRecent` | `true` | boolean |
| `launcherShowShortcutHints` | `true` | boolean |
| `launcherShowPreview` | `false` | boolean |
| `launcherShowIcons` | `true` | boolean |
| `launcherGridColumns` | `6` | 2–12 |
| `launcherGridIconSize` | `64` | 32–128 |
| `launcherResultSpacing` | `6` | 0–24 |
| `launcherPadding` | `16` | 4–40 |
| `launcherSearchHeight` | `68` | 40–100 |
| `launcherSearchFontSize` | `22` | 12–32 |
| `launcherAnimationStyle` | `"inherit"` | inherit / none / fade / scale / slide / float / spring |
| `detachedLauncherGap` | `10` | 0–32 |
| `detachedLauncherInputHeight` | `64` | 44–96 |
| `detachedLauncherInputFontSize` | `21` | 14–32 |
| `detachedLauncherInputRadius` | `18` | 0–48 |
| `detachedLauncherResultsRadius` | `16` | 0–48 |
| `detachedLauncherPlaceholder` | `"Search applications, files, notes…"` | string, ≤160 characters, no control characters |
| `detachedLauncherShowIcon` | `true` | boolean |
| `detachedLauncherShowHint` | `true` | boolean |
| `detachedLauncherResultMode` | `"adaptive"` | list / grid / adaptive |
| `detachedLauncherAppLayout` | `"grid"` | list / grid |
| `detachedLauncherResultWidthMode` | `"match-input"` | match-input / custom |
| `detachedLauncherResultsWidth` | `660` | 320–1600 |
| `detachedLauncherExpansionDirection` | `"auto"` | auto / down / up |
| `detachedLauncherResultAlignment` | `"center"` | left / center / right |
| `detachedLauncherMaxResults` | `24` | 1–100 |
| `detachedLauncherShowEmptyResults` | `false` | boolean |
| `detachedLauncherInputGlassEnabled` | `true` | boolean |
| `detachedLauncherResultsGlassEnabled` | `true` | boolean |
| `detachedLauncherInputBackgroundEnabled` | `true` | boolean |
| `detachedLauncherResultsBackgroundEnabled` | `true` | boolean |
| `detachedLauncherInputOutlineEnabled` | `true` | boolean |
| `detachedLauncherResultsOutlineEnabled` | `true` | boolean |
| `detachedLauncherInputInheritMaterial` | `true` | boolean |
| `detachedLauncherResultsInheritMaterial` | `true` | boolean |
| `detachedLauncherInputOpacity` | `0.4` | 0.15–1 |
| `detachedLauncherResultsOpacity` | `0.5` | 0.15–1 |
| `detachedLauncherInputHighlights` | `true` | boolean |
| `detachedLauncherResultsHighlights` | `true` | boolean |
| `detachedLauncherInputShadowIntensity` | `0.14` | 0–0.6 |
| `detachedLauncherResultsShadowIntensity` | `0.14` | 0–0.6 |
| `launcherUseStyleDefaults` | `true` | boolean |

`launcherOpacity=-1` and `launcherCornerRadius=-1` mean inherit. Other negative opacity values are rejected. Integer fields reject fractional JSON values. Slider setters clamp to bounds and commit once on release. Invalid JSON, types and unknown enums retain safe defaults.

`launcherUseStyleDefaults=true` selects recommended geometry for modern styles. Legacy styles always honor saved dimensions. Customizing shared width/height/search geometry disables automatic geometry; this flag survives reload. Detached input height/font and its two radii always use their dedicated values.

`launcherBackdropMode=auto` uses the selected style’s documented default. Explicit None/Dim/Blur/Dim and Blur/Focus overrides every style. Selecting a style does not rewrite the backdrop preference, geometry, palette or material preferences.

`resetLauncherAppearance()` resets these appearance fields while preserving the selected style. `resetDetachedLauncherAppearance()` resets only `detachedLauncher*` fields. Neither resets unrelated shell settings.
