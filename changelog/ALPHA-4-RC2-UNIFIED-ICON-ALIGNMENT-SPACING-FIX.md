# Alpha 4 RC2 — Unified Bar Icon Placement and Spacing (fix only)

- Moved Mic, Download and Upload toggles to **Settings → Modules → Status indicators**, consistent with the other icon toggles. Default remains disabled.
- Removed duplicate **Extra status icons** card from Bar settings. All 17 existing icons, including optional indicators, use one **Bar icon alignment** editor.
- **Icon spacing** now supports **Left / Center / Right** groups. Its icon choices follow the icon's actual assigned zone automatically.
- Moving an icon migrates its existing Before/After spacing to the new group for **each bar layout mode**, preserving manual tuning and avoiding lost/duplicated margins.
- Vertical bars use the same spacing preferences, where Left / Center / Right become Top / Middle / Bottom and Before / After become top/bottom item margins.
- Existing RC2 JSON settings are migrated in memory and remain backward-compatible. The patch does **not** include `user-settings.json`.

## Smoke test
1. In Modules, enable Download speed.
2. In Bar icon alignment, move Download to Center.
3. Open Icon spacing → Center, select Download, adjust Before / After.
4. Move Download to Left and verify values follow.
5. Switch among Compact, Clean Compact, Separated, Professional, Simple and test both horizontal and vertical bars.
