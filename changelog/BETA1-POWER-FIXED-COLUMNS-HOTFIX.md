# Beta 1 — Power Menu Fixed-Column Alignment Hotfix

## Corrected

- The title and subtitle of the header and every power action now start at the same fixed x coordinate. The icon centers are aligned and keyboard shortcut digits are pinned to a single right-edge column.
- Removes content-sized nested `RowLayout`s that caused text to shift depending on label length (e.g. Screensaver compared with Lock, Reboot and Shutdown).
- Keeps the centered panel, colors, border, `PanelWindow`/Wayland Overlay layer, keyboard navigation, confirmation interaction and native Omarchy ASCII screensaver unchanged.

## Install

Unzip the **patch archive** into the directory *containing* the `quickshell` folder, e.g. `unzip -o rusticq-beta1-power-fixed-columns-patch.zip -d ~/dev`, then restart `qs -p .` from your source folder. No installer is included.

## Validation

`python3 tools/test_beta1_power_alignment_grid.py` tests fixed-column bindings, no horizontal `RowLayout` in the power menu, safe widths and unchanged power actions. No live Wayland compositor was available for rendering; check the result in Hyprland after applying the patch.
