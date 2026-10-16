# RusticQ Alpha 3 RC1 — Layout & Optional Menu Bar

**Target:** Quickshell 0.3.1 (Arch Linux), Hyprland Wayland. Based on `rustiq-alpha-3`, with the same Gruvbox/Aether tokens, Poppins type and bundled Google Material Symbols.

## Changelog

- **Reduced outer gaps**: top and bottom now use 4px in compact and 6px for standard modes; horizontal inset is 6px, side rails use 4px. Professional remains flush with the screen edges.
- **Professional** uses Alpha 2's 44px height, inner 17px margin, centered between flexible spacers for the title, and a subtle accent separator. The title hides automatically when there isn't enough room.
- **Left/Right layouts** now respond to all five selections. `compact` is dense, `clean-compact` removes control surfaces, `separated` groups controls in rounded islands, `professional` uses a full solid rail with dividers, and `simple` shows the essentials (AI, time, Quick Control). Modes are immediately applied to all monitors.
- **Mini widgets:** the popup's exterior backdrop and border are disabled only for Wi-Fi, Bluetooth and Battery; each underlying card retains its own border and padding. The full Quick Control is unchanged.
- **Optional menu bar:** Settings → Bar & modules → **Tahoe-inspired menu bar**. Default OFF. Shows **Edit**, **View**, **Share** to the left of workspace icons on spacious horizontal bars and a single menu glyph on vertical rails.
- **Edit** opens RusticQ Appearance/Bar/AI settings. **View** switches the five bar layouts directly. **Share** captures the screen/region locally to `~/Pictures/Screenshots/` (or `XDG_PICTURES_DIR/Screenshots`) using `grim` and optionally `slurp`, or opens that directory via `xdg-open`. These are **RusticQ shortcuts**, not the menus of the currently focused app, nor a global-menu/DBus integration.
- **Responsive control:** the horizontal menu labels automatically hide when the bar is less than 981px wide; the option stays saved and works as an icon on vertical rails. Changing the selected mode/position closes the old popup to avoid stale geometry.

## Dependencies

Core: Quickshell 0.3.1, Hyprland and the existing RusticQ dependencies. For Share screenshot actions only:

```sh
sudo pacman -S grim slurp xdg-utils
```

If `grim`/`slurp` are missing, those specific actions will not capture anything; the rest of RusticQ continues to function. Captures remain local. No network upload is performed.

## Install and test

1. Extract to a **new directory** (archive root: `quickshell/`), back up your existing settings before replacing the old files.
2. Run `qs -p ./quickshell` from the archive's parent directory.
3. Go to **Full Settings → Bar & modules** and select every combination of Top/Bottom/Left/Right and Compact/Clean Compact/Separated/Professional/Simple. Check monitors of different sizes, workspaces, indicators and click targets.
4. Test one mini widget at a time, checking that only the **interior** card has a border; test the full Quick Control separately.
5. Turn on the Tahoe-inspired menu bar, open Edit, View and Share; change mode from View and verify the popup closes; try screenshot capture if dependencies are installed. Turn menu OFF to verify the default design.
6. Verify menu remains reachable in vertical layouts, and that popup geometry stays inside the screen.
7. Run `python tools/verify-static.py`, `python tools/test_rustiq_alpha3_rc1.py` for code checks.

### Known limitations

The build environment has no `qs` binary or running Hyprland compositor, so runtime visual tests and screenshot/DBus behavior are **not** confirmed here. Menus do not reflect the active app's File/Edit menu. `grim` requires an accessible Wayland screencopy protocol. Capturing a region requires `slurp`. Power status and network still require their respective services.

## Next good candidates (not included in RC1)

- Per-monitor bar mode/edge overrides instead of global positioning.
- Real app menu integration for GTK/Qt over the appropriate protocols, with graceful fallback.
- Keyboard-accessible global command palette and configurable keybindings.
- UI screenshot regression testing in a nested Hyprland/Wayland session.
