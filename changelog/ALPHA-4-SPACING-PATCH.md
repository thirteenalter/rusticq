# RusticQ Alpha 4 — Spacing editor correction

This is a correction of Alpha 4, not a new release series.

- Removed duplicate Wi-Fi/Battery spacer and reduced `Indicators` pill horizontal padding from 14px to 6px (5px in compact).
- Default indicator gap is now 3px in compact modes and 4px otherwise (instead of up to 12px plus an extra spacer).
- Added Settings → Bar → Icon spacing · Left / Right. Select a side and an individual icon to configure the baseline group gap (0–16px) and icon Before/After (0–24px).
- Reuses the same control on each of the five bar modes. Top/Bottom use horizontal margins; Left/Right rails map the values to vertical spacing.
- A new `barSpacingOverrides` object is validated when reading `user-settings.json`, preserving existing settings and rejecting invalid values.
- Reset icon and Reset this side clear selected overrides. No extra fonts or external daemons.

Source-level validation is not a replacement for testing the QML in Quickshell 0.3.1 on Hyprland.
