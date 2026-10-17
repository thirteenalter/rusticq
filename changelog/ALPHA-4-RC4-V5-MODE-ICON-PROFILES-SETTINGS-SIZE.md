# RusticQ Alpha 4 RC4 · v5 — Layout icon profiles & Settings dimensions

## Bar icons belong to their layout mode

- Each of `compact`, `clean-compact`, `separated`, `professional`, and `simple` now owns independent **icon visibility**, **menu buttons**, **Quick Modes button visibility**, and **Left / Center / Right placements**.
- Spacing and edge margins were already per mode and remain per mode. Moving an icon only moves its custom spacing in that mode.
- Choose **Settings → Bar → Bar layout**, then toggle **Icon preferences**. Changes are applied live to the active layout and saved in `user-settings.json`.
- **Minimal** provides a compact set of essential icons for the selected mode; **Reset mode** restores default visibility just for that mode. **Copy from** clones another mode's icon visibility into the current mode without linking the profiles.
- Advanced toggles for File/Edit/View/Share/Shell/Tools menus and individual Quick Modes actions are under **Settings → Modules**, also applied only to the active mode.
- On a *fresh* install, Simple defaults to fewer icons. **Existing RC4 `user-settings.json` files are migrated**, keeping the previous global icon preferences in all five modes as the initial baseline, to avoid disrupting user configurations.
- Notification toast delivery and Quick Modes auto-hide remain global behavior settings. A hidden bar button does not disable its feature or keyboard shortcut.

## Settings window sizing

- Target **1100 × 760 logical pixels**, with clamping for smaller monitors.
- Updates both `modules/settings/SettingsWindow.qml` **and** `scripts/rustiq-settings-float.py` to avoid Hyprland forcing the obsolete 940 × 600 size.
- Window remains floating, centered on open, and user-resizable.

## Installation

- **Full**: extract `rusticq-alpha4-rc4-v5-full.zip` into the parent of the `quickshell` directory (e.g. `~/dev`).
- **Patch**: extract `rusticq-alpha4-rc4-v5-patch.zip` directly into the existing `~/dev/quickshell` directory, overwriting matching source files. Requires v4 (top bar shortcuts) as the base.
- No installer shell script, no change to Omarchy, and no automatic replacement of the active shell.
- Full ZIP deliberately **omits personal/runtime JSON (`user-settings.json`, `app-usage.json`)** to prevent overwriting your local preferences. Font binaries are not bundled.
- Restart with `qs -p .` from the `quickshell` directory.

## Verification

- `python3 tools/test_rc4_v5_mode_profiles.py` exercises extracted QML JavaScript functions in Node and checks settings size calculations with mocked Hyprland monitors.
- Real visual integration across different monitor scales still requires testing on an actual Hyprland session.
